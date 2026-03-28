#!/bin/sh
#
# install-ai-satellite.sh
# Configures and starts services for an AI inference satellite host.
#
# Network notes:
#   - nginx-proxy-manager creates nginx-proxy-net locally.
#   - sensors2mqtt requires mosquitto-net to exist. Either run mosquitto
#     locally or ensure the network is available via an overlay before
#     starting this script.
#
# comfy-ui is only installed on x86_64/AMD64 hosts; it is skipped on ARM.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

# ============================================================
# Dependency order:
#
# Tier 0 - no external network dependencies
#   nginx-proxy-manager   creates: nginx-proxy-net
#   ollama                creates: llama-net
#   dnsmasq               no networks
#
# Tier 1 - needs proxy
#   dozzle (agent only)   no network deps (exposes port 7007 for central dozzle)
#   comfy-ui              needs: proxy  [x86_64/AMD64 only]
#
# Tier 2 - needs mqtt-net (external - mosquitto must already be running)
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

echo "==> Configuring apps..."
for app in $AI_SATELLITE_APPS; do
    echo "  Configuring $app..."
    configure_app "$app"
done

case "$(uname -m)" in
    x86_64|i?86)
        echo "  Configuring comfy-ui ($(uname -m) detected)..."
        configure_app comfy-ui
        ;;
    *)
        echo "  Skipping comfy-ui (not supported on $(uname -m))"
        ;;
esac

echo ""
echo "==> Starting apps in dependency order..."
start_app nginx-proxy-manager
start_app ollama
start_app dnsmasq

# Run dozzle in agent-only mode - this satellite reports to the central
# dozzle UI rather than hosting its own.
start_app_service dozzle agent

start_app sensors2mqtt

case "$(uname -m)" in
    x86_64|i?86)
        start_app comfy-ui
        ;;
esac

echo ""
echo "Done. Run 'docker ps' to verify all services are up."
