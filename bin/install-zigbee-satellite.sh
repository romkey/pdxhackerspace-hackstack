#!/bin/sh

. ./bin/lib.sh

install_default_config zigbee2mqtt
start_app zigbee2mqtt

install_default_config watchtower
start_app zigbee2mqtt
