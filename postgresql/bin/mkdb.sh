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

export USER=$1_user
export DATABASE=$1_db
export PASSWORD=`pwgen 24 1`

echo "Will create this database:"
echo
echo "database: ${DATABASE}"
echo "username: ${USER}"
echo "password: ${PASSWORD}"
echo
echo

source ../postgresql/.env
: ${POSTGRES_USER:=postgresql}

echo "1. creating user"
CMD="docker compose -f ../postgresql/docker-compose.yml exec postgresql createuser -U ${POSTGRES_USER} -w ${USER}"
echo "    ${CMD}"
$CMD

echo "2. creating database owned by user"
CMD="docker compose -f ../postgresql/docker-compose.yml exec postgresql createdb -U ${POSTGRES_USER} ${DATABASE} -O ${USER}"
echo "    ${CMD}"
$CMD

echo "3. adding database URL for backups to .env"

export BACKUP_DATABASES="BACKUP_DATABASES=postgres://${USER}:${PASSWORD}@postgresql/${DATABASE}"

if  pwd | grep -q postgresql ; then
    echo "You are in Postgresql's directory. You should add or replace BACKUP_DATABASES in your applications .env file"
    echo "${BACKUP_DATABASES}"
else
    if grep -qF BACKUP_DATABASES .env; then
	echo ".env already has BACKUP_DATABASES variable, not updating"
	echo "You should update it by hand with the new variable"
        echo "${BACKUP_DATABASES}"
    else
        if echo "${BACKUP_DATABASES}" >> .env ; then
	    echo "Automatically added BACKUP_DATABASES to your .env file"
	else
	    echo "Failed to write to .env file, please add BACKUP_DATABASES by hand"
	fi
    fi
    echo "${BACKUP_DATABASES}"
fi

	
