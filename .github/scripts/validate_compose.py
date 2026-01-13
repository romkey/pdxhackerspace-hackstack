#!/usr/bin/env python3
"""
Docker Compose Validator for Hackstack

Validates docker-compose.yml files against project conventions.
See .cursor/rules/docker-compose.mdc for the full rule set.
"""

import sys
import re
import yaml
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ValidationResult:
    """Represents a validation finding."""
    level: str  # "error", "warning", "info"
    rule: str
    message: str
    file: str
    service: Optional[str] = None
    line: Optional[int] = None


@dataclass
class ValidationReport:
    """Collects all validation results."""
    results: list = field(default_factory=list)
    
    def add(self, level: str, rule: str, message: str, file: str, 
            service: Optional[str] = None, line: Optional[int] = None):
        self.results.append(ValidationResult(level, rule, message, file, service, line))
    
    def error(self, rule: str, message: str, file: str, service: Optional[str] = None):
        self.add("error", rule, message, file, service)
    
    def warning(self, rule: str, message: str, file: str, service: Optional[str] = None):
        self.add("warning", rule, message, file, service)
    
    def info(self, rule: str, message: str, file: str, service: Optional[str] = None):
        self.add("info", rule, message, file, service)
    
    @property
    def errors(self):
        return [r for r in self.results if r.level == "error"]
    
    @property
    def warnings(self):
        return [r for r in self.results if r.level == "warning"]
    
    @property
    def has_errors(self):
        return len(self.errors) > 0


# Database images that should use shared instances
FORBIDDEN_DB_IMAGES = [
    r'postgres',
    r'postgresql',
    r'mariadb',
    r'mysql',
    r'mongo',
]

# Exceptions for certain rules
RESTART_EXCEPTIONS = {'bfg-repo-cleaner', 'mailq', 'postfix-base'}  # CLI tools and YAML anchors that shouldn't restart
PORT_EXCEPTIONS = {
    'nginx-proxy-manager',  # Needs ports for proxy
    'mosquitto',            # MQTT broker
    'postfix',              # Mail relay
    'rsyslog',              # Syslog server
    'upsd',                 # UPS daemon
    'netboot',              # PXE boot
    'dozzle',               # Agent needs port
}
HOST_MODE_EXCEPTIONS = {
    'snapserver',
    'shairport-sync', 
    'airconnect',
    'music-assistant',
    'dnsmasq',
}

# Multi-service stacks where service names differ from container names intentionally
# Format: (service_dir, service_name) -> allowed container_name prefix
MULTI_SERVICE_EXCEPTIONS = {
    # Authentik stack
    ('authentik', 'redis'): 'authentik-',
    ('authentik', 'server'): 'authentik-',
    ('authentik', 'worker'): 'authentik-',
    # Dozzle with agent
    ('dozzle', 'agent'): 'dozzle-',
    # Database variants for port exposure
    ('mariadb', 'mariadb-ports'): 'mariadb',
    ('postgresql', 'postgresql-ports'): 'postgresql',
}

# Environment variables that are allowed to be embedded (not from .env)
ALLOWED_EMBEDDED_ENV = {
    # Authentik internal service discovery
    'AUTHENTIK_REDIS__HOST',
    # Netboot configuration
    'MENU_VERSION',
    'NGINX_PORT', 
    'WEB_APP_PORT',
}


def validate_compose_file(file_path: Path, report: ValidationReport):
    """Validate a single docker-compose.yml file."""
    
    file_str = str(file_path)
    service_dir = file_path.parent.name
    compose_dir = file_path.parent
    
    # Read raw content for line-level checks
    try:
        raw_content = file_path.read_text()
    except Exception as e:
        report.error("file-read", f"Cannot read file: {e}", file_str)
        return
    
    # Parse YAML
    try:
        data = yaml.safe_load(raw_content)
    except yaml.YAMLError as e:
        report.error("yaml-syntax", f"Invalid YAML: {e}", file_str)
        return
    
    if not data:
        report.warning("empty-file", "File is empty or invalid", file_str)
        return
    
    # Rule 1: No version field
    if 'version' in data:
        report.error("no-version", "docker-compose files should not have a 'version' field", file_str)
    
    # Rule: Check for .env.example if env_file is used
    services = data.get('services', {})
    uses_env_file = any(
        svc.get('env_file') for svc in services.values() if svc
    )
    if uses_env_file:
        env_example = compose_dir / '.env.example'
        if not env_example.exists():
            report.error("env-example-missing",
                "Missing .env.example file (required when using env_file)",
                file_str)
    
    # Rule: Config directory naming convention
    # Check for config dirs with wrong names (conf, configuration, etc.)
    wrong_config_names = ['conf', 'configuration', 'cfg', 'settings']
    for wrong_name in wrong_config_names:
        wrong_dir = compose_dir / wrong_name
        if wrong_dir.exists() and wrong_dir.is_dir():
            report.warning("config-dir-naming",
                f"Configuration directory should be named 'config', not '{wrong_name}'",
                file_str)
    
    # Rule: Must have a README file
    readme_exists = any(
        (compose_dir / name).exists() 
        for name in ['README.md', 'README', 'README.txt', 'readme.md']
    )
    if not readme_exists:
        report.error("readme-missing",
            "Missing README.md file (should explain service function, configuration, and start/stop)",
            file_str)
    
    # Rule 2: Check for named volumes (non-NFS)
    if 'volumes' in data and isinstance(data['volumes'], dict):
        for vol_name, vol_config in data['volumes'].items():
            if vol_config is None:
                report.error("no-named-volumes", 
                    f"Named volume '{vol_name}' should be a bind mount (not a Docker volume)", 
                    file_str)
            elif isinstance(vol_config, dict):
                driver_opts = vol_config.get('driver_opts', {})
                if driver_opts.get('type') != 'nfs':
                    report.error("no-named-volumes",
                        f"Named volume '{vol_name}' should be a bind mount unless it's NFS",
                        file_str)
    
    # Validate each service
    services = data.get('services', {})
    if not services:
        report.warning("no-services", "No services defined", file_str)
        return
    
    for service_name, service_config in services.items():
        if not service_config:
            continue
            
        validate_service(service_name, service_config, file_path, report, raw_content)


def validate_service(service_name: str, config: dict, file_path: Path, 
                     report: ValidationReport, raw_content: str):
    """Validate a single service definition."""
    
    file_str = str(file_path)
    service_dir = file_path.parent.name
    
    # Rule 3: Service name should match hostname and container_name
    hostname = config.get('hostname')
    container_name = config.get('container_name')
    
    # Check for multi-service stack exceptions
    exception_key = (service_dir, service_name)
    allowed_prefix = MULTI_SERVICE_EXCEPTIONS.get(exception_key)
    
    if hostname and hostname != service_name:
        # Allow if it matches the exception prefix pattern
        if allowed_prefix and (hostname.startswith(allowed_prefix) or hostname == allowed_prefix):
            pass  # Exception allowed
        else:
            report.error("name-match", 
                f"hostname '{hostname}' should match service name '{service_name}'",
                file_str, service_name)
    
    if container_name and container_name != service_name:
        # Allow if it matches the exception prefix pattern
        if allowed_prefix and (container_name.startswith(allowed_prefix) or container_name == allowed_prefix):
            pass  # Exception allowed
        else:
            report.error("name-match",
                f"container_name '{container_name}' should match service name '{service_name}'",
                file_str, service_name)
    
    # Rule 4: restart: unless-stopped
    restart = config.get('restart')
    if service_name not in RESTART_EXCEPTIONS:
        if restart is None:
            report.error("restart-policy",
                "Missing 'restart: unless-stopped'",
                file_str, service_name)
        elif restart not in ('unless-stopped', 'no'):
            report.error("restart-policy",
                f"restart should be 'unless-stopped', got '{restart}'",
                file_str, service_name)
    
    # Rule 5 & 11: Environment variables from .env, no embedded constants
    env_file = config.get('env_file')
    environment = config.get('environment')
    
    if environment:
        if isinstance(environment, dict):
            for key, value in environment.items():
                # Skip allowed embedded env vars
                if key in ALLOWED_EMBEDDED_ENV:
                    continue
                # Check if it's a constant (no variable interpolation)
                if value is not None and not isinstance(value, bool):
                    value_str = str(value)
                    if '${' not in value_str and not value_str.startswith('$'):
                        report.error("no-env-constants",
                            f"Environment variable '{key}={value}' should come from .env, not be embedded",
                            file_str, service_name)
        elif isinstance(environment, list):
            for item in environment:
                if '=' in item:
                    key, value = item.split('=', 1)
                    # Skip allowed embedded env vars
                    if key in ALLOWED_EMBEDDED_ENV:
                        continue
                    if '${' not in value and not value.startswith('$'):
                        report.error("no-env-constants",
                            f"Environment variable '{item}' should come from .env",
                            file_str, service_name)
    
    # Rule 6: Image tags should use ${IMAGE_VERSION:-...}
    image = config.get('image')
    if image:
        # Check if it's using a build instead
        if 'build' not in config:
            # Check if image already uses an env var for the tag (${...} pattern)
            # The `:${` pattern indicates tag is an env var
            if ':${' in image:
                # Already using env var for tag - OK
                pass
            elif ':' in image:
                # Has a tag - check if it's a literal value
                # Need to handle registries with ports like docker.io:5000/image:tag
                # Find the last colon that's followed by a tag (not a port or path)
                parts = image.rsplit(':', 1)  # Split from right, max 1 split
                if len(parts) == 2:
                    tag_part = parts[1]
                    # If tag contains '/' it's actually part of the path, not a tag
                    if '/' in tag_part:
                        # No actual tag, just registry path
                        report.error("image-version-env",
                            f"Image '{image}' should specify tag with ${{IMAGE_VERSION:-latest}}",
                            file_str, service_name)
                    else:
                        # This is a literal tag
                        report.error("image-version-env",
                            f"Image tag should use env var: '{image}' -> use ${{IMAGE_VERSION:-{tag_part}}}",
                            file_str, service_name)
            else:
                # No colon at all - no tag specified
                report.error("image-version-env",
                    f"Image '{image}' should specify tag with ${{IMAGE_VERSION:-latest}}",
                    file_str, service_name)
    
    # Rule 12: Ports should be commented out (warning)
    ports = config.get('ports')
    if ports and service_dir not in PORT_EXCEPTIONS:
        report.warning("no-ports",
            f"Ports should typically be commented out (found: {ports})",
            file_str, service_name)
    
    # Rule 13-16: Volume path conventions
    volumes = config.get('volumes', [])
    if isinstance(volumes, list):
        for vol in volumes:
            if isinstance(vol, str):
                # Parse host:container format
                if ':' in vol:
                    host_path = vol.split(':')[0]
                    check_volume_path(host_path, file_str, service_name, report)
                    
    # Rule 17: Healthcheck warning
    if 'healthcheck' not in config:
        report.warning("no-healthcheck",
            "Consider adding a healthcheck",
            file_str, service_name)
    
    # Rule 18: Host mode warning
    network_mode = config.get('network_mode')
    if network_mode == 'host' and service_dir not in HOST_MODE_EXCEPTIONS:
        report.warning("host-mode",
            "Container uses host network mode - ensure this is necessary",
            file_str, service_name)
    
    # Rule 19: No networks declared (and not host mode)
    networks = config.get('networks')
    if network_mode != 'host' and not networks:
        report.warning("no-networks",
            "No networks declared - consider adding proxy/db networks as needed",
            file_str, service_name)
    
    # Rule 20: Forbidden database images
    if image:
        image_lower = image.lower()
        for db_pattern in FORBIDDEN_DB_IMAGES:
            # Skip if this IS the shared database service
            if service_dir in ('postgresql', 'mariadb', 'redis'):
                continue
            # Check if image contains forbidden DB
            if re.search(rf'\b{db_pattern}\b', image_lower):
                # Exception for redis used as cache within a stack (like authentik)
                if 'redis' in image_lower and service_dir in ('authentik', 'membermatters'):
                    continue
                report.error("no-embedded-db",
                    f"Don't embed database '{image}' - use the shared service instead",
                    file_str, service_name)


def check_volume_path(host_path: str, file_str: str, service_name: str, report: ValidationReport):
    """Check if volume paths follow conventions."""
    
    # Skip environment variable paths
    if host_path.startswith('${'):
        return
    
    # Skip read-only system mounts
    if host_path.startswith('/var/run') or host_path.startswith('/run'):
        return
    if host_path.startswith('/etc/'):
        return
    if host_path.startswith('/dev/'):
        return
        
    # Check for absolute paths (should use relative)
    if host_path.startswith('/'):
        # Exception for /media mounts
        if not host_path.startswith('/media'):
            report.warning("relative-paths",
                f"Use relative paths instead of absolute: '{host_path}'",
                file_str, service_name)
    
    # Check relative paths follow convention
    if host_path.startswith('../../'):
        if '/lib/' in host_path or host_path.startswith('../../lib'):
            pass  # Good - persistent state
        elif '/log/' in host_path or host_path.startswith('../../log'):
            pass  # Good - log files
        elif '/run/' in host_path or host_path.startswith('../../run'):
            pass  # Good - transient state


def find_compose_files(root_dir: Path) -> list:
    """Find all docker-compose.yml files in the project."""
    compose_files = []
    
    for path in root_dir.rglob('docker-compose.yml'):
        # Skip .github directory
        if '.github' in path.parts:
            continue
        compose_files.append(path)
    
    # Also check for docker-compose.*.yml variants
    for path in root_dir.rglob('docker-compose.*.yml'):
        if '.github' not in path.parts:
            compose_files.append(path)
    
    return sorted(compose_files)


def format_results(report: ValidationReport, github_actions: bool = False) -> str:
    """Format validation results for output."""
    
    lines = []
    
    if github_actions:
        # GitHub Actions annotation format
        for r in report.results:
            level_prefix = {
                'error': '::error',
                'warning': '::warning',
                'info': '::notice'
            }.get(r.level, '::notice')
            
            location = f"file={r.file}"
            if r.service:
                msg = f"[{r.rule}] {r.service}: {r.message}"
            else:
                msg = f"[{r.rule}] {r.message}"
            
            lines.append(f"{level_prefix} {location}::{msg}")
    else:
        # Human-readable format
        current_file = None
        for r in report.results:
            if r.file != current_file:
                current_file = r.file
                lines.append(f"\n📁 {r.file}")
            
            icon = {'error': '❌', 'warning': '⚠️', 'info': 'ℹ️'}.get(r.level, '•')
            service_prefix = f"[{r.service}] " if r.service else ""
            lines.append(f"  {icon} {r.level.upper()}: {service_prefix}{r.message}")
    
    return '\n'.join(lines)


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Validate docker-compose.yml files')
    parser.add_argument('files', nargs='*', help='Files to validate (default: find all)')
    parser.add_argument('--github-actions', action='store_true', 
                        help='Output in GitHub Actions annotation format')
    parser.add_argument('--root', type=Path, default=Path('.'),
                        help='Project root directory')
    parser.add_argument('--warnings-as-errors', action='store_true',
                        help='Treat warnings as errors')
    
    args = parser.parse_args()
    
    report = ValidationReport()
    
    if args.files:
        # Validate specific files
        files = [Path(f) for f in args.files]
    else:
        # Find all compose files
        files = find_compose_files(args.root)
    
    if not files:
        print("No docker-compose.yml files found")
        return 0
    
    print(f"Validating {len(files)} docker-compose file(s)...\n")
    
    for file_path in files:
        validate_compose_file(file_path, report)
    
    # Output results
    if report.results:
        print(format_results(report, args.github_actions))
        print()
    
    # Summary
    error_count = len(report.errors)
    warning_count = len(report.warnings)
    
    print(f"\n{'='*50}")
    print(f"Summary: {error_count} error(s), {warning_count} warning(s)")
    
    if error_count > 0:
        print("❌ Validation failed")
        return 1
    elif warning_count > 0 and args.warnings_as_errors:
        print("❌ Validation failed (warnings as errors)")
        return 1
    else:
        print("✅ Validation passed")
        return 0


if __name__ == '__main__':
    sys.exit(main())
