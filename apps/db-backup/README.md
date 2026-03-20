# db-backup

Continuous database backup service for PostgreSQL, MySQL/MariaDB, SQLite, and
Redis. Automatically discovers databases by scanning application directories
for `.env` files containing `BACKUP_DATABASE_URLS`, backs them up on a
configurable interval, and applies tiered retention (hourly/daily/weekly/
monthly/yearly).

Image: [romkey/hackstack-db-backup](https://github.com/romkey/hackstack-db-backup)
(`ghcr.io/romkey/hackstack-db-backup`)

## How it works

On each backup cycle, the service scans every subdirectory under `PARENT_DIR`
for a `.env` file. If that file contains a `BACKUP_DATABASE_URLS` variable,
each URL in the comma-separated list is backed up and compressed with bzip2.

Backup files land in `DEST_DIR/<app_name>/backup-<db>-<timestamp>.sql.bz2`.

## Configuring an application for backup

Add this to the application's `.env` file (not the db-backup `.env`):

```bash
BACKUP_DATABASE_URLS="postgresql://user:pass@postgresql:5432/mydb"
```

Multiple databases can be comma-separated:

```bash
BACKUP_DATABASE_URLS="postgresql://user:pass@postgresql:5432/db1,redis://:pass@redis:6379/0"
```

Supported URL schemes: `postgresql://`, `mysql://`, `sqlite:///`, `redis://`

### PostgreSQL per-database vs cluster globals

`BACKUP_DATABASE_URLS` runs **`pg_dump`** per database. That does **not** include cluster-wide objects: roles, role memberships, database-level defaults, tablespaces, and similar metadata. To capture those, the backup image runs **`pg_dumpall --globals-only`** when configured (see **`PG_GLOBALS_URL`** below).

Without **`PG_GLOBALS_URL`**, the service may still attempt a globals dump using credentials from the **first** `postgresql://…` URL discovered under `PARENT_DIR`. Those URLs are usually **application users**, not superusers, so the globals step is often **skipped** (insufficient privileges). For reliable globals backups, set **`PG_GLOBALS_URL`** to a **superuser** connection.

### Creating a dedicated PostgreSQL superuser for globals backup

Use a **dedicated** superuser role (least surprise when rotating app passwords). From the host, with the PostgreSQL container running:

```bash
cd apps/postgresql
# load admin user from compose env (default superuser in the image)
source .env
ADMIN="${POSTGRES_USER:-postgresql}"
```

Open **`psql`** as that admin:

```bash
docker compose exec postgresql psql -U "$ADMIN" -d postgres
```

In **`psql`**, create a login role used only for backups (pick a strong password, e.g. from `pwgen 32 1`):

```sql
CREATE ROLE db_backup_globals WITH LOGIN SUPERUSER PASSWORD 'replace-with-strong-password';
```

**Security:** treat this password like root DB access. Restrict who can read **`db-backup`** `.env` and your secrets store.

You can instead reuse the cluster’s bootstrap superuser (`POSTGRES_USER` / `POSTGRES_PASSWORD` from `apps/postgresql/.env`) in **`PG_GLOBALS_URL`**, but rotating that password is more disruptive than rotating a dedicated backup role.

### `PG_GLOBALS_URL` (db-backup `.env`)

Set this in **`apps/db-backup/.env`** (not in per-app `.env` files). The [hackstack-db-backup](https://github.com/romkey/hackstack-db-backup) image reads it each backup cycle.

| Property | Notes |
|----------|--------|
| **Format** | `postgresql://USER:PASSWORD@HOST:PORT/DBNAME` |
| **Scheme** | Must be **`postgresql://`**. (`postgres://` is not parsed for this feature.) |
| **Privileges** | User must be a **superuser** (or otherwise allowed to run `pg_dumpall --globals-only`). |
| **DBNAME** | Not used for the globals dump; use `postgres` (or any DB the user can connect to). |
| **Hostname** | From the **`dbbackup`** container, the shared service is usually **`postgresql`** on `postgres-net`. |

Example:

```bash
PG_GLOBALS_URL=postgresql://db_backup_globals:your-password@postgresql:5432/postgres
```

**Output file:** `DEST_DIR/postgresql/backup-globals-postgresql-5432-<timestamp>.sql.bz2` (compressed with the same retention logic as other backups under that folder).

If **`PG_GLOBALS_URL`** is unset, globals backup is only attempted with credentials inferred from discovered app URLs and may be skipped if those users are not superusers.

**Special characters in passwords** must be **URL-encoded** in `PG_GLOBALS_URL` (e.g. `@` → `%40`, `:` → `%3A`).

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PARENT_DIR` | Yes | `/opt/docker` | Path **inside** the container to scan for app subdirectories |
| `DEST_DIR` | Yes | `/dest` | Path **inside** the container where backups are written |
| `DBBACKUP_PARENT_HOST_PATH` | Yes | `/opt` | Host path mounted as `/opt` in the container (must contain `PARENT_DIR`) |
| `DBBACKUP_DEST_PATH` | Yes | — | Host path mounted as `/dest` in the container |
| `BACKUP_INTERVAL_MINUTES` | No | `60` | Minutes between backup cycles |
| `SLACK_WEBHOOK_URL` | No | — | Slack webhook URL for notifications |
| `BACKUP_RETAIN_HOURLY` | No | `6` | Hourly backups to keep |
| `BACKUP_RETAIN_DAILY` | No | `6` | Daily backups to keep |
| `BACKUP_RETAIN_WEEKLY` | No | `6` | Weekly backups to keep |
| `BACKUP_RETAIN_MONTHLY` | No | `6` | Monthly backups to keep |
| `BACKUP_RETAIN_YEARLY` | No | `6` | Yearly backups to keep |
| `IMAGE_VERSION` | No | `latest` | Docker image tag |
| `PG_GLOBALS_URL` | No | — | `postgresql://` URL with a **superuser** used for `pg_dumpall --globals-only` (roles / cluster metadata). See [PostgreSQL globals](#postgresql-per-database-vs-cluster-globals). |

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
