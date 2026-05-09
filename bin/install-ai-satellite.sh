#!/bin/sh
#
# install-ai-satellite.sh
# Two-phase install: setup without starting containers, then "start".
#
# Network notes:
#   - nginx-proxy-manager creates nginx-proxy-net locally.
#   - sensors2mqtt requires mosquitto-net to exist. Either run mosquitto
#     locally or ensure the network is available via an overlay before
#     the start phase.
#
# comfy-ui is only installed on x86_64/AMD64 hosts; it is skipped on ARM.

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

# ============================================================
# Dependency order:
#
# Tier 0 - no external network dependencies
#   nginx-proxy-manager   creates: nginx-proxy-net
#   ollama                creates: llama-net
#   dnsmasq               no networks
#
# Tier 1 - needs proxy
#   dozzle-agent          agent service
#   comfy-ui              needs: proxy  [x86_64/AMD64 only]
#
# Tier 2 - needs mqtt-net (external - must exist before start)
#   sensors2mqtt          needs: mqtt
# ============================================================

AI_SATELLITE_APPS="
nginx-proxy-manager
ollama
dnsmasq
dozzle-agent
sensors2mqtt
watchtower
"

if [ "$MODE" = "configure" ]; then
    echo "==> Phase 1: setup (no Docker containers will be started)"
    echo ""

    echo "==> Configuring apps..."
    for app in $AI_SATELLITE_APPS; do
        echo "  Configuring $app..."
        configure_app "$app"
    done

    case "$(uname -m)" in
        x86_64|i?86)
            echo "  Configuring comfy-ui experiment ($(uname -m) detected)..."
            configure_app_experiment comfy-ui
            ;;
        *)
            echo "  Skipping comfy-ui (not supported on $(uname -m))"
            ;;
    esac

    echo ""
    echo "==> Configure these before running: $(basename "$0") start"
    echo "    (paths relative to repo root $REPO_ROOT):"
    echo ""
    print_config_paths_for_apps $AI_SATELLITE_APPS
    case "$(uname -m)" in
        x86_64|i?86)
            print_config_paths_for_experiments comfy-ui
            ;;
    esac
    print_two_phase_next_step
    echo "Setup phase complete."
    exit 0
fi

echo "==> Phase 2: starting apps in dependency order..."

start_app nginx-proxy-manager
start_app ollama
start_app dnsmasq

start_app_service dozzle-agent agent

start_app sensors2mqtt

case "$(uname -m)" in
    x86_64|i?86)
        start_experiment comfy-ui
        ;;
esac

start_app watchtower

echo ""
echo "Done. Run 'docker ps' to verify all services are up."
