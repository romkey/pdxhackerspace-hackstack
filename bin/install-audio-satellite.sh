#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

install_default_config snapclient snapcast dozzle-agent watchtower
start_app snapclient

echo "Do you want to install Airplay (shairport-sync) support? (yes/no)"
read answer

if [ "$answer" = "yes" ]; then
    install_default_config shairport-sync shairport-sync
    start_app shairport-sync
else
    echo "Skipping Airplay (shairport-sync)"
fi

install_default_config watchtower
