#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib.sh"

install_default_config zigbee2mqtt dozzle-agent watchtower
start_app zigbee2mqtt

install_default_config watchtower
start_app zigbee2mqtt
