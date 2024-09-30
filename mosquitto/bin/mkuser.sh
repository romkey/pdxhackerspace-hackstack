#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <application name>"
    exit 1
fi

if [ ! command -v pwgen 2>&1 > /dev/null ]; then
    echo "pwgen not found, needed to generate password"
    echo "install using 'apt install pwgen'"
    exit 1
fi

export USER=$1
export PASSWORD=`pwgen 24 1`

echo "Will create this user:"
echo
echo "username: ${USER}"
echo "password: ${PASSWORD}"
echo "broker: mosquitto"
echo "port: 1883"
echo "url: mqtt://${USER}:${PASSWORD}@mosquitto:1883"
echo
echo "Only usable from within a hackstack container. To use externally, replace 'mosquitto' with the name or IP address of this server"

echo "creating user:"
CMD="docker compose -f ../docker-compose.yml exec mosquitto mosquitto_passwd -b /mosquitto/data/mos_passwd ${USER} ${PASSWORD}"
echo "    ${CMD}"
if $CMD ; then
    echo "successful"
else
    echo "failed"
fi

