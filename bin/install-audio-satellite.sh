#!/bin/sh

source ./lib.sh

install_default_config snapclient snapcast
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
