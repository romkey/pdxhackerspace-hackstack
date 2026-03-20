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

# Resolve paths from this script so it works when run from any app under apps/ or experiments/
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MARIADB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$MARIADB_DIR/docker-compose.yml"

export USER=$1_user
export DATABASE=$1_db
export PASSWORD=$(pwgen 24 1)

echo "Will create this database:"
echo
echo "database: ${DATABASE}"
echo "username: ${USER}"
echo "password: ${PASSWORD}"
echo
echo

# shellcheck source=/dev/null
source "$MARIADB_DIR/.env"

if [ -z "${MARIADB_ROOT_PASSWORD}" ]; then
    echo "Error: MARIADB_ROOT_PASSWORD is not set in $MARIADB_DIR/.env" >&2
    exit 1
fi

echo "Using MariaDB root from $MARIADB_DIR/.env"
echo

echo "Checking if MariaDB container is running..."
if ! docker compose -f "$COMPOSE_FILE" ps mariadb | grep -q "Up"; then
    echo "Error: MariaDB container is not running"
    echo "Please start it with: docker compose -f $COMPOSE_FILE up -d mariadb"
    exit 1
fi
echo "✓ MariaDB container is running"
echo

echo "1. creating user, database, and grants"
echo "    docker compose -f $COMPOSE_FILE exec -T mariadb mariadb -u root -p*** ..."
if docker compose -f "$COMPOSE_FILE" exec -T mariadb mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" << EOF
CREATE USER IF NOT EXISTS '${USER}'@'%' IDENTIFIED BY '${PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${DATABASE}\`;
GRANT ALL PRIVILEGES ON \`${DATABASE}\`.* TO '${USER}'@'%';
FLUSH PRIVILEGES;
EOF
then
    echo "    ✓ User, database, and grants applied"
else
    echo "    ✗ Failed to create user/database or apply grants"
    exit 1
fi

echo "2. adding database URL for backups to .env"

export BACKUP_DATABASE_URLS="BACKUP_DATABASE_URLS=mysql://${USER}:${PASSWORD}@mariadb:3306/${DATABASE}"

APP_CWD=$(pwd -P)
if [ "$APP_CWD" = "$MARIADB_DIR" ]; then
    echo "You are in the MariaDB service directory. Add or replace BACKUP_DATABASE_URLS in your application's .env file:"
    echo "${BACKUP_DATABASE_URLS}"
else
    if [ ! -f .env ]; then
        echo "No .env in $(pwd); create it from .env.example, then add:" >&2
        echo "${BACKUP_DATABASE_URLS}" >&2
    elif grep -qF BACKUP_DATABASE_URLS .env 2>/dev/null; then
        echo ".env already has BACKUP_DATABASE_URLS variable, not updating"
        echo "You should update it by hand with the new variable"
    else
        if echo "${BACKUP_DATABASE_URLS}" >> .env; then
            echo "Automatically added BACKUP_DATABASE_URLS to your .env file"
        else
            echo "Failed to write to .env file, please add BACKUP_DATABASE_URLS by hand"
        fi
    fi
    echo "${BACKUP_DATABASE_URLS}"
fi

echo
echo "Database setup complete!"
echo "Connection details:"
echo "  Host: mariadb"
echo "  Port: 3306"
echo "  Database: ${DATABASE}"
echo "  Username: ${USER}"
echo "  Password: ${PASSWORD}"
echo "  Connection URL: mysql://${USER}:${PASSWORD}@mariadb:3306/${DATABASE}"
