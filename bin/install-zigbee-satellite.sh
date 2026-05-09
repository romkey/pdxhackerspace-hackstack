#!/bin/sh
#
# install-zigbee-satellite.sh
# Two-phase install: setup without starting containers, then "start".

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

case "${1:-}" in
    "") MODE=configure ;;
    start) MODE=start ;;
    *)
        two_phase_usage
        exit 1
        ;;
esac

# Order matches typical dependencies: proxy net first, then supporting services, zigbee2mqtt, watchtower.
ZIGBEE_SATELLITE_APPS="
nginx-proxy-manager
glances
dozzle-agent
zigbee2mqtt
watchtower
"

if [ "$MODE" = "configure" ]; then
    echo "==> Phase 1: setup (no Docker containers will be started)"
    echo ""

    for app in $ZIGBEE_SATELLITE_APPS; do
        echo "  Configuring $app..."
        configure_app "$app"
    done

    print_config_checklist $ZIGBEE_SATELLITE_APPS
    echo "Setup phase complete."
    exit 0
fi

echo "==> Phase 2: starting apps..."
start_app nginx-proxy-manager
start_app glances
start_app_service dozzle-agent agent
start_app zigbee2mqtt
start_app watchtower

echo ""
echo "Done. Run 'docker ps' to verify all services are up."
