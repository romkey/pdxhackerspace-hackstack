#!/bin/sh
#
# install-chaos.sh
# Two-phase install: (1) setup configs and system packages without starting
# containers; (2) start with "start" after .env/config are ready.
#
# All networks used by services in this script are created by services within
# this script once you run the start phase. No external prerequisites required.

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
# Service list in dependency order:
#
# Tier 0 - no external network dependencies (or create their own from scratch)
#   nginx-proxy-manager   creates: nginx-proxy-net
#   mosquitto             creates: mosquitto-net
#   ollama                creates: llama-net
#   mdns-repeater         creates: mdns-net (and ipvlan_net)
#   cloudflare-ddns       no networks
#   postfix               creates: postfix-net
#   rsyslog               no networks
#   snapserver            host network mode
#
# Tier 1 - needs proxy
#   postgresql            creates: postgres-net   needs: proxy
#   mariadb               creates: mariadb-net    needs: proxy
#   dnsmasq               needs: (none)
#   dozzle                needs: proxy
#   glances               needs: proxy
#   cyberchef             needs: proxy
#   peanut                needs: proxy
#
# Tier 2 - needs proxy + db, mariadb, mqtt, llama, or mail
#   event-manager         needs: proxy, db, mail
#   invidious             needs: proxy, db
#   member-manager        needs: proxy, db, mail
#   partdb                needs: proxy, db
#   planka                needs: proxy, db
#   statping              needs: proxy, db
#   vaultwarden           needs: proxy, db
#   matomo                creates: matomo-net     needs: proxy, mariadb
#   mosquitto-management-center  needs: proxy, mqtt
#   mqtt-explorer         needs: proxy, mqtt
#   openwebui             needs: proxy, llama
#
# Tier 3 - needs proxy + mqtt + db + llama + mdns
#   home-assistant        creates: hass-net       needs: proxy, mqtt, db,
#                                                         llama, mdns
#
# Tier 4 - needs hass and/or mdns
#   piper                 needs: hass
#   whisper               needs: hass
#   matter                needs: hass, mdns
#   jellyfin              needs: proxy, db, hass, mdns
#   mopidy                needs: proxy, mdns
#
# Tier 5 - needs db + mariadb
#   db-backup             needs: db, mariadb
# ============================================================

CHAOS_APPS="
nginx-proxy-manager
mosquitto
ollama
mdns-repeater
cloudflare-ddns
postfix
rsyslog
snapserver
postgresql
mariadb
dnsmasq
dozzle
glances
cyberchef
peanut
event-manager
invidious
member-manager
partdb
planka
statping
vaultwarden
matomo
mosquitto-management-center
mqtt-explorer
openwebui
home-assistant
piper
whisper
matter
jellyfin
mopidy
db-backup
"

if [ "$MODE" = "configure" ]; then
    echo "==> Phase 1: setup (no Docker containers will be started)"
    echo ""

    echo "==> Installing system packages..."
    sudo apt-get install -y cups
    sudo systemctl enable --now cups
    echo "CUPS installed and enabled."
    echo ""

    echo "==> Configuring all apps..."
    for app in $CHAOS_APPS; do
        echo "  Configuring $app..."
        configure_app "$app"
    done

    print_config_checklist $CHAOS_APPS
    echo "Setup phase complete."
    exit 0
fi

echo "==> Phase 2: starting apps in dependency order..."
for app in $CHAOS_APPS; do
    start_app "$app"
done

echo ""
echo "Done. Run 'docker ps' to verify all services are up."
