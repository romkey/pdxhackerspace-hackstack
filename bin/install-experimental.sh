#!/bin/sh
#
# install-experimental.sh
# Two-phase install for optional experiment services.
#
# Prerequisites (must be running before the start phase):
#   nginx-proxy-manager   nginx-proxy-net
#   mariadb               mariadb-net

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
# ============================================================

EXPERIMENTAL_APPS="
mediawiki
uptime-kuma
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
        configure_app_experiment "$exp"
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
