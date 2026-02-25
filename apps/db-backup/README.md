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
