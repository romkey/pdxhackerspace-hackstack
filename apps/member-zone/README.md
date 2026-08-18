# member-zone

PDX Hackerspace member management application (image: [pdxhackerspace/member-zone](https://github.com/pdxhackerspace/member-manager)). Rails web app with a Sidekiq background job worker and a private Redis instance for job queuing.

## Services

| Container | Role |
|-----------|------|
| `member-zone` | Rails web server (port 3000, behind reverse proxy) |
| `member-zone-sidekiq` | Sidekiq background job worker |
| `member-zone-redis` | Private Redis for Sidekiq (no AOF; `save 900 1` only—see [redis-persistence-hackstack.md](../../docs/redis-persistence-hackstack.md)) |

## Network dependencies

| Network | Provided by | Purpose |
|---------|-------------|---------|
| `nginx-proxy-net` | nginx-proxy-manager | Reverse proxy access |
| `postgres-net` | postgresql | Database |
| `postfix-net` | postfix | Outbound email |

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `RAILS_ENV` | Rails environment (`production`) |
| `SECRET_KEY_BASE` | Rails secret key — generate with `openssl rand -hex 64` |
| `DATABASE_URL` | PostgreSQL connection URL |
| `REDIS_URL` | Redis connection URL (points to internal `member-zone-redis`) |
| `SMTP_HOST` | SMTP server hostname (default: `postfix` via postfix-net) |
| `SMTP_PORT` | SMTP port |
| `SMTP_FROM` | From address for outgoing mail |
| `APP_HOST` | Public hostname for URL generation |
| `IMAGE_VERSION` | Web/sidekiq image tag (optional, defaults to `latest`) |
| `REDIS_IMAGE_VERSION` | Redis image tag (optional, defaults to `7-alpine`) |

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

### Running Rails tasks

```bash
docker compose exec web bundle exec rails <task>
```
