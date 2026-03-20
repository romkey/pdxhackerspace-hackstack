# Postgresql

Use the convenience script located in `bin/mkdb.sh` to create a database and its owner and the owner's password.

**Change directory to the application** that needs PostgreSQL (under `apps/` or `experiments/`), then run the script by path. The script resolves the PostgreSQL compose project from its own location, so the same invocation works from any app directory.

Examples:

```bash
# from apps/someapp
../postgresql/bin/mkdb.sh someapp

# from experiments/someapp
../../apps/postgresql/bin/mkdb.sh someapp
```

Where `APPLICATION` is the name of the application (the argument to `mkdb.sh`).

This will:
1. create a database named `APPLICATION_db`
2. create a user which owns the database named `APPLICATION_user`
3. create a strong password for the user
4. if your current directory is **not** the `apps/postgresql` service directory, it will append a `BACKUP_DATABASE_URLS` line to `.env` in the current directory unless that file already contains `BACKUP_DATABASE_URLS`
5. output the info for the database

Alternatively you can run commands to make the database and user yourself.


These examples assume that the administrative user for Postgresql is `postgresql`. If you've used another name, substitute it for `postgresql`.

## Create User

```
docker compose exec postgresql createuser -U postgresql -w USERNAME
```
this will prompt for a password.


## Create Database
```
docker compose exec postgresql createdb NAME -O OWNER_NAME;
```

##  Change a user or role's password
```
docker compose exec postgresql psql -U postgresql
alter role NAME with password PASSWORD;
```

To grant privileges:
```
docker compose exec postgresql psql -U postgresql
grant all on database DATABASE to USER;
```

# Dump (backup) database
```
docker compose exec postgresql pg_dump -U postgresql DATABASE > database.psql
```

# Restore database
```
docker compose exec -T postgresql psql -U postgresql DATABASE < database.psql
```


