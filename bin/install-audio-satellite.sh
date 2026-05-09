#!/bin/sh
#
# install-audio-satellite.sh
# Two-phase install: setup (optional AirPlay prompt) without starting containers, then "start".

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

AIRPLAY_FLAG="$SCRIPT_DIR/.install-audio-satellite-airplay"

case "${1:-}" in
    "") MODE=configure ;;
    start) MODE=start ;;
    *)
        two_phase_usage
        exit 1
        ;;
esac

AUDIO_CORE_APPS="
snapclient
dozzle-agent
nginx-proxy-manager
watchtower
"

if [ "$MODE" = "configure" ]; then
    echo "==> Phase 1: setup (no Docker containers will be started)"
    echo ""

    for app in $AUDIO_CORE_APPS; do
        echo "  Configuring $app..."
        configure_app "$app"
    done

    echo "Do you want to install AirPlay (shairport-sync) support? (yes/no)"
    read answer
    if [ "$answer" = "yes" ]; then
        echo "  Configuring shairport-sync..."
        configure_app shairport-sync
        echo "yes" >"$AIRPLAY_FLAG"
    else
        echo "Skipping Airplay (shairport-sync)"
        rm -f "$AIRPLAY_FLAG"
    fi

    CHECKLIST_APPS=$AUDIO_CORE_APPS
    if [ "$answer" = "yes" ]; then
        CHECKLIST_APPS="$AUDIO_CORE_APPS
shairport-sync"
    fi

    print_config_checklist $CHECKLIST_APPS
    echo "Setup phase complete."
    exit 0
fi

echo "==> Phase 2: starting apps..."

start_app nginx-proxy-manager
start_app_service dozzle-agent agent
start_app watchtower
start_app snapclient

if [ -f "$AIRPLAY_FLAG" ] && [ "$(cat "$AIRPLAY_FLAG")" = "yes" ]; then
    start_app shairport-sync
fi

echo ""
echo "Done. Run 'docker ps' to verify all services are up."
