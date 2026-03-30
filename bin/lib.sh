# lib.sh
# Meant to be included in other scripts, not run directly.
#
# The calling script should set REPO_ROOT and SCRIPT_DIR before sourcing:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
#   . "$SCRIPT_DIR/lib.sh"
#
# App service directories are expected at $REPO_ROOT/apps/<name>.
# APPS_ROOT is set automatically to $REPO_ROOT/apps.

if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

APPS_ROOT="$REPO_ROOT/apps"
EXPERIMENTS_ROOT="$REPO_ROOT/experiments"

_get_system_tz() {
    if [ -f /etc/timezone ]; then
        cat /etc/timezone
    elif command -v timedatectl > /dev/null 2>&1; then
        timedatectl show --property=Timezone --value 2>/dev/null
    else
        readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||'
    fi
}

configure_app_experiment() {
    dir="$EXPERIMENTS_ROOT/$1"
    config_file="$2"

    if [ ! -d "$dir" ]; then
        echo "  (experiment $1 missing under experiments/, skipping)"
        return 0
    fi

    if [ -n "$config_file" ] && [ -f "$dir/config/$config_file.default" ] && [ ! -f "$dir/config/$config_file" ]; then
        cp "$dir/config/$config_file.default" "$dir/config/$config_file"
        echo "Installed experiments/$1/config/$config_file - review for configuration changes"
    fi

    if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
        cp "$dir/.env.example" "$dir/.env"
        echo "Installed experiments/$1/.env - review for configuration changes"
    fi

    if [ -f "$dir/.env" ]; then
        tz=$(_get_system_tz)
        if [ -n "$tz" ]; then
            if grep -q '^TZ=' "$dir/.env"; then
                sed -i "s|^TZ=.*|TZ=$tz|" "$dir/.env"
            else
                echo "TZ=$tz" >> "$dir/.env"
            fi
            echo "  Set TZ=$tz in experiments/$1/.env"
        fi
    fi
}

configure_app() {
    dir="$APPS_ROOT/$1"
    config_file="$2"

    if [ -n "$config_file" ] && [ -f "$dir/config/$config_file.default" ] && [ ! -f "$dir/config/$config_file" ]; then
        cp "$dir/config/$config_file.default" "$dir/config/$config_file"
        echo "Installed $1/config/$config_file - review for configuration changes"
    fi

    if [ -f "$dir/.env.example" ] && [ ! -f "$dir/.env" ]; then
        cp "$dir/.env.example" "$dir/.env"
        echo "Installed $1/.env - review for configuration changes"
    fi

    if [ -f "$dir/.env" ]; then
        tz=$(_get_system_tz)
        if [ -n "$tz" ]; then
            if grep -q '^TZ=' "$dir/.env"; then
                sed -i "s|^TZ=.*|TZ=$tz|" "$dir/.env"
            else
                echo "TZ=$tz" >> "$dir/.env"
            fi
            echo "  Set TZ=$tz in $1/.env"
        fi
    fi
}

# kept for backward compatibility
install_default_config() {
    configure_app "$1" "$2"
}

start_app() {
    app_dir="$APPS_ROOT/$1"
    if ! docker compose -f "$app_dir/docker-compose.yml" ps 2>/dev/null | grep -q 'Up'; then
        echo "Starting $1..."
        docker compose -f "$app_dir/docker-compose.yml" up -d
        echo "$1 started."
    else
        echo "$1 is already running."
    fi
}

# Start a single named service within an app's compose file, leaving other
# services in that file untouched.
# Usage: start_app_service <app_dir> <service_name>
start_experiment() {
    exp_dir="$EXPERIMENTS_ROOT/$1"
    if [ ! -d "$exp_dir" ]; then
        echo "experiment $1: directory missing, skipping"
        return 0
    fi
    if ! docker compose -f "$exp_dir/docker-compose.yml" ps 2>/dev/null | grep -q 'Up'; then
        echo "Starting experiment $1..."
        docker compose -f "$exp_dir/docker-compose.yml" up -d
        echo "$1 started."
    else
        echo "experiment $1 is already running."
    fi
}

start_app_service() {
    app_dir="$APPS_ROOT/$1"
    service="$2"
    if ! docker compose -f "$app_dir/docker-compose.yml" ps "$service" 2>/dev/null | grep -q 'Up'; then
        echo "Starting $1/$service..."
        docker compose -f "$app_dir/docker-compose.yml" up -d "$service"
        echo "$1/$service started."
    else
        echo "$1/$service is already running."
    fi
}

# Usage message for two-phase installers (setup without Docker vs start).
two_phase_usage() {
    me=$(basename "$0")
    echo "Usage: $me [start]" >&2
    echo "" >&2
    echo "  (no arguments)  Setup only: install configs/packages and .env templates." >&2
    echo "                  Does not start Docker containers. At the end, configure" >&2
    echo "                  the listed files, then run:" >&2
    echo "                  $me start" >&2
    echo "" >&2
    echo "  start           Start all Docker services for this installer." >&2
}

# Print apps/<app>/.env and config paths (repo-relative). One or more app names.
print_config_paths_for_apps() {
    for app in "$@"; do
        dir="$APPS_ROOT/$app"
        if [ ! -d "$dir" ]; then
            continue
        fi
        if [ -f "$dir/.env.example" ]; then
            echo "  apps/$app/.env"
        fi
        for def in "$dir/config/"*.default; do
            [ -f "$def" ] || continue
            base=$(basename "$def" .default)
            echo "  apps/$app/config/$base"
        done
    done
}

# Same as print_config_paths_for_apps but under experiments/<name>/.
print_config_paths_for_experiments() {
    for exp in "$@"; do
        dir="$EXPERIMENTS_ROOT/$exp"
        if [ ! -d "$dir" ]; then
            continue
        fi
        if [ -f "$dir/.env.example" ]; then
            echo "  experiments/$exp/.env"
        fi
        for def in "$dir/config/"*.default; do
            [ -f "$def" ] || continue
            base=$(basename "$def" .default)
            echo "  experiments/$exp/config/$base"
        done
    done
}

print_two_phase_next_step() {
    echo ""
    echo "Then run: $(basename "$0") start"
    echo ""
}

# List .env and config files operators should edit before the start pass.
# Pass app directory names (e.g. nginx-proxy-manager). Paths are repo-relative (apps/...).
print_config_checklist() {
    echo ""
    echo "==> Configure these before running: $(basename "$0") start"
    echo "    (paths relative to repo root $REPO_ROOT):"
    echo ""
    print_config_paths_for_apps "$@"
    print_two_phase_next_step
}
