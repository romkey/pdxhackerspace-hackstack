#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <application name>"
    exit 1
fi

if ! command -v pwgen >/dev/null 2>&1; then
    echo "pwgen not found, needed to generate password"
    echo "install using 'apt install pwgen'"
    exit 1
fi

# Resolve paths from this script so it works when run from any app under apps/, experiments/ or local/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOSQUITTO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$MOSQUITTO_DIR/docker-compose.yml"
CONFIG_FILE="$MOSQUITTO_DIR/config/mosquitto.conf"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found"
    exit 1
fi

# The password file must be the one the broker actually reads, otherwise the new user is
# written somewhere mosquitto never looks at. Take it from mosquitto.conf when possible.
PASSWD_FILE=/mosquitto/config/mos_passwd
if [ -f "$CONFIG_FILE" ]; then
    conf_passwd_file=$(sed -n 's/^[[:space:]]*password_file[[:space:]]\+//p' "$CONFIG_FILE" | tail -n 1)
    conf_passwd_file="${conf_passwd_file%"${conf_passwd_file##*[![:space:]]}"}"
    if [ -n "$conf_passwd_file" ]; then
        # collapse doubled slashes, eg "/mosquitto//config/mos_passwd"
        PASSWD_FILE=$(echo "$conf_passwd_file" | tr -s /)
    fi
else
    echo "Warning: $CONFIG_FILE not found, assuming password file ${PASSWD_FILE}"
fi

MQTT_USER=$1
MQTT_PASSWORD=$(pwgen 24 1)

echo "Creating this user:"
echo
echo "username: ${MQTT_USER}"
echo "password: ${MQTT_PASSWORD}"
echo "broker: mosquitto"
echo "port: 1883"
echo "url: mqtt://${MQTT_USER}:${MQTT_PASSWORD}@mosquitto:1883"
echo
echo "Only usable from within a hackstack container. To use externally, replace 'mosquitto' with the name or IP address or name of this server"
echo

echo "Checking if mosquitto container is running..."
if ! docker compose -f "$COMPOSE_FILE" ps mosquitto | grep -q "Up"; then
    echo "Error: mosquitto container is not running"
    echo "Please start it with: docker compose -f $COMPOSE_FILE up -d mosquitto"
    exit 1
fi
echo "✓ mosquitto container is running"
echo

# mosquitto_passwd needs -c to create the file the first time, but -c truncates an existing file
passwd_opts=(-b)
if ! docker compose -f "$COMPOSE_FILE" exec -T mosquitto test -f "$PASSWD_FILE"; then
    echo "${PASSWD_FILE} does not exist yet, it will be created"
    passwd_opts=(-b -c)
fi

echo "1. creating user in ${PASSWD_FILE}"
echo "    docker compose -f $COMPOSE_FILE exec mosquitto mosquitto_passwd ${passwd_opts[*]} $PASSWD_FILE ${MQTT_USER} <password>"
if docker compose -f "$COMPOSE_FILE" exec -T mosquitto \
       mosquitto_passwd "${passwd_opts[@]}" "$PASSWD_FILE" "$MQTT_USER" "$MQTT_PASSWORD"; then
    echo "    ✓ User created successfully"
else
    echo "    ✗ Failed to create user"
    exit 1
fi

echo "2. forcing mosquitto to reload its password file"
# SIGHUP to PID 1 in the container - mosquitto rereads its config and password file
if docker compose -f "$COMPOSE_FILE" kill -s HUP mosquitto; then
    echo "    ✓ Reload signal sent"
else
    echo "    ✗ Failed to signal mosquitto"
    exit 1
fi

# the reload is asynchronous, give the broker a moment before testing the new credentials
sleep 2

echo "3. verifying the new credentials"
# exit status 5 means the broker refused the login, anything else means authentication worked
# (a subscribe may still be denied by acl_file, which is not an authentication failure)
docker compose -f "$COMPOSE_FILE" exec -T mosquitto \
    mosquitto_sub -h localhost -p 1883 -u "$MQTT_USER" -P "$MQTT_PASSWORD" -t '$SYS/broker/uptime' -C 1 -W 3 \
    >/dev/null 2>&1
if [ "$?" -eq 5 ]; then
    echo "    ✗ Broker refused the new credentials, the password file was not reloaded"
    exit 1
fi
echo "    ✓ Broker accepted the new credentials"

echo
echo "MQTT user setup complete!"
echo "Connection details:"
echo "  Host: mosquitto"
echo "  Port: 1883"
echo "  Username: ${MQTT_USER}"
echo "  Password: ${MQTT_PASSWORD}"
echo "  Connection URL: mqtt://${MQTT_USER}:${MQTT_PASSWORD}@mosquitto:1883"
