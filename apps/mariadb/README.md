# mariadb

MySQL-compatible relational database

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

Set **`MARIADB_ROOT_PASSWORD`** in `apps/mariadb/.env`; `bin/mkdb.sh` uses it to create application databases.

### Creating an application database

From **`bin/mkdb.sh`**: creates `APPLICATION_user`, `APPLICATION_db`, and a random password; optionally appends **`BACKUP_DATABASE_URLS`** (MySQL URL) to the app’s `.env`.

**Change directory to the application** under `apps/` or `experiments/`, then run:

```bash
# from apps/someapp
../mariadb/bin/mkdb.sh someapp

# from experiments/someapp
../../apps/mariadb/bin/mkdb.sh someapp
```

If you run the script **from** `apps/mariadb`, it only prints the `BACKUP_DATABASE_URLS` line for you to copy into the app’s `.env`.

## Usage

### Starting the service

```bash
docker compose up -d
```

### Stopping the service

```bash
docker compose down
```

### Viewing logs

```bash
docker compose logs -f
```
