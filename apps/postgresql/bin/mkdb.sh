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
POSTGRESQL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$POSTGRESQL_DIR/docker-compose.yml"

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
source "$POSTGRESQL_DIR/.env"
: "${POSTGRES_USER:=postgresql}"

echo "Using PostgreSQL admin user: ${POSTGRES_USER}"
echo

# Check if PostgreSQL container is running
echo "Checking if PostgreSQL container is running..."
if ! docker compose -f "$COMPOSE_FILE" ps postgresql | grep -q "Up"; then
    echo "Error: PostgreSQL container is not running"
    echo "Please start it with: docker compose -f $COMPOSE_FILE up -d postgresql"
    exit 1
fi
echo "✓ PostgreSQL container is running"
echo

echo "1. creating user"
echo "    docker compose -f $COMPOSE_FILE exec postgresql createuser -U ${POSTGRES_USER} -w ${USER}"
if docker compose -f "$COMPOSE_FILE" exec postgresql createuser -U "${POSTGRES_USER}" -w "${USER}"; then
    echo "    ✓ User created successfully"
else
    echo "    ✗ Failed to create user"
    exit 1
fi

echo "2. creating database owned by user"
echo "    docker compose -f $COMPOSE_FILE exec postgresql createdb -U ${POSTGRES_USER} ${DATABASE} -O ${USER}"
if docker compose -f "$COMPOSE_FILE" exec postgresql createdb -U "${POSTGRES_USER}" "${DATABASE}" -O "${USER}"; then
    echo "    ✓ Database created successfully"
else
    echo "    ✗ Failed to create database"
    exit 1
fi

echo "3. setting user password"
echo "    Setting password for ${USER}..."
if docker compose -f "$COMPOSE_FILE" exec -T postgresql psql -U "${POSTGRES_USER}" -d postgres << EOF
ALTER ROLE ${USER} WITH PASSWORD '${PASSWORD}';
EOF
then
    echo "    ✓ Password set successfully"
else
    echo "    ✗ Failed to set password"
    exit 1
fi

echo "4. adding database URL for backups to .env"

export BACKUP_DATABASE_URLS="BACKUP_DATABASE_URLS=postgres://${USER}:${PASSWORD}@postgresql/${DATABASE}"

APP_CWD=$(pwd -P)
if [ "$APP_CWD" = "$POSTGRESQL_DIR" ]; then
    echo "You are in the PostgreSQL service directory. Add or replace BACKUP_DATABASE_URLS in your application's .env file:"
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
echo "  Host: postgresql"
echo "  Port: 5432"
echo "  Database: ${DATABASE}"
echo "  Username: ${USER}"
echo "  Password: ${PASSWORD}"
echo "  Connection URL: postgres://${USER}:${PASSWORD}@postgresql/${DATABASE}"
