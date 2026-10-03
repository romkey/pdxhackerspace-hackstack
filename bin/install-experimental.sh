#!/bin/sh
#
# install-experimental.sh
# Two-phase install for optional experiment services.
#
# Prerequisites (must be running before the start phase):
#   nginx-proxy-manager   nginx-proxy-net
#   mariadb               mariadb-net
#   postgresql            postgres-net

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
# Tier 0 - prerequisites (not started by this script)
#   nginx-proxy-manager   creates: nginx-proxy-net
#   mariadb               creates: mariadb-net
#
# Tier 1 - needs proxy + mariadb
#   mediawiki             needs: proxy, mariadb
#
# Tier 1 - needs proxy only
#   uptime-kuma           needs: proxy
#   copyparty             needs: proxy
#   filebrowser-quantum   needs: proxy
#
# Tier 1 - needs proxy + postgresql
#   forgejo               needs: proxy, postgresql
# ============================================================

EXPERIMENTAL_APPS="
mediawiki
uptime-kuma
copyparty
filebrowser-quantum
forgejo
"

if [ "$MODE" = "configure" ]; then
    echo "==> Phase 1: setup (no Docker containers will be started)"
    echo ""
    echo "Prerequisites: nginx-proxy-manager and mariadb must be configured and"
    echo "running before you run: $(basename "$0") start"
    echo ""

    echo "==> Configuring experiments..."
    for exp in $EXPERIMENTAL_APPS; do
        echo "  Configuring $exp..."
        case "$exp" in
            copyparty) configure_app_experiment "$exp" copyparty.conf ;;
            filebrowser-quantum) configure_app_experiment "$exp" config.yaml ;;
            *) configure_app_experiment "$exp" ;;
        esac
    done

    echo ""
    echo "==> Before starting mediawiki:"
    echo "  1. From experiments/mediawiki, create the database:"
    echo "       cd experiments/mediawiki"
    echo "       ../../apps/mariadb/bin/mkdb.sh mediawiki"
    echo "  2. Create the images directory:"
    echo "       mkdir -p ../../lib/mediawiki/images"
    echo "  3. After the web installer, save LocalSettings.php to ../../lib/mediawiki/"
    echo "     and uncomment its bind mount in experiments/mediawiki/docker-compose.yml"
    echo ""

    echo "==> Before starting uptime-kuma:"
    echo "  1. Create the data directory:"
    echo "       mkdir -p ../../lib/uptime-kuma"
    echo "  2. Monitors, notifications and the admin account are set up in the web UI"
    echo "     on first run; point the proxy at uptime-kuma:3001"
    echo ""

    echo "==> Before starting copyparty:"
    echo "  1. Create the data directories, owned by PUID:PGID from .env (default 1000):"
    echo "       mkdir -p ../../lib/copyparty/cfg ../../lib/copyparty/files/public ../../lib/copyparty/files/internal"
    echo "  2. In experiments/copyparty/config/copyparty.conf, change the admin and lan passwords"
    echo "  3. Point the proxy at copyparty:3923"
    echo ""

    echo "==> Before starting filebrowser-quantum:"
    echo "  1. Create the data directories, owned by PUID:PGID from .env (default 1000):"
    echo "       mkdir -p ../../lib/filebrowser-quantum/data ../../lib/filebrowser-quantum/files"
    echo "  2. Set FILEBROWSER_ADMIN_PASSWORD in experiments/filebrowser-quantum/.env"
    echo "  3. Point the proxy at filebrowser-quantum:80"
    echo ""

    echo "==> Before starting forgejo:"
    echo "  1. From experiments/forgejo, create the database:"
    echo "       cd experiments/forgejo"
    echo "       ../../apps/postgresql/bin/mkdb.sh forgejo"
    echo "     and put the password in .env as FORGEJO__database__PASSWD"
    echo "  2. Create the data directory, owned by USER_UID:USER_GID from .env (default 1000):"
    echo "       mkdir -p ../../lib/forgejo"
    echo "  3. Set FORGEJO__server__DOMAIN and ROOT_URL in .env, then point the"
    echo "     proxy at forgejo:3000"
    echo ""

    echo "==> Configure these before running: $(basename "$0") start"
    echo "    (paths relative to repo root $REPO_ROOT):"
    echo ""
    print_config_paths_for_experiments $EXPERIMENTAL_APPS
    print_two_phase_next_step
    echo "Setup phase complete."
    exit 0
fi

echo "==> Phase 2: starting experiments in dependency order..."
for exp in $EXPERIMENTAL_APPS; do
    start_experiment "$exp"
done

echo ""
echo "Done. Run 'docker ps' to verify all services are up."
