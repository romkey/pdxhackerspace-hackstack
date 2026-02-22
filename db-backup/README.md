# db-backup

Scheduled PostgreSQL database backup service. Runs on a configurable cron
schedule, dumps one or more databases, and stores compressed backup files in
`../../lib/db-backup`.

Image source: [romkey/pdxhackstack-db-backup](https://github.com/romkey/pdxhackstack-db-backup)

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_HOST` | PostgreSQL hostname | `postgresql` |
| `POSTGRES_PORT` | PostgreSQL port | `5432` |
| `POSTGRES_USER` | Database user | _(required)_ |
| `POSTGRES_PASSWORD` | Database password | _(required)_ |
| `POSTGRES_DATABASES` | Comma-separated list of databases to back up | all databases |
| `BACKUP_SCHEDULE` | Cron schedule for backups | `0 3 * * *` (3am daily) |
| `BACKUP_RETENTION_DAYS` | Number of days to retain backups | `7` |
| `IMAGE_VERSION` | Docker image tag | `latest` |

### Backup Storage

Backups are stored in `../../lib/db-backup` on the host, which maps to
`/backups` inside the container.

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

### Triggering a manual backup

```bash
docker compose exec db-backup /backup.sh
```
