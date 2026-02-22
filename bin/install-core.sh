#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

CORE_APPS="
nginx-proxy-manager
dnsmasq
glances
"

echo "==> Configuring apps..."
for app in $CORE_APPS; do
    echo "Configuring $app..."
    configure_app "$app"
done

echo ""
echo "==> Starting apps..."
for app in $CORE_APPS; do
    start_app "$app"
done
