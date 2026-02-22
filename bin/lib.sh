# lib.sh
# Meant to be included in other scripts, not run directly.
#
# The calling script should set REPO_ROOT and SCRIPT_DIR before sourcing:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
#   . "$SCRIPT_DIR/lib.sh"

if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

_get_system_tz() {
    if [ -f /etc/timezone ]; then
        cat /etc/timezone
    elif command -v timedatectl > /dev/null 2>&1; then
        timedatectl show --property=Timezone --value 2>/dev/null
    else
        readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||'
    fi
}

configure_app() {
    dir="$REPO_ROOT/$1"
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
    app_dir="$REPO_ROOT/$1"
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
start_app_service() {
    app_dir="$REPO_ROOT/$1"
    service="$2"
    if ! docker compose -f "$app_dir/docker-compose.yml" ps "$service" 2>/dev/null | grep -q 'Up'; then
        echo "Starting $1/$service..."
        docker compose -f "$app_dir/docker-compose.yml" up -d "$service"
        echo "$1/$service started."
    else
        echo "$1/$service is already running."
    fi
}
