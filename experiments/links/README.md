# links (experiment)

Rails link shortener and printer status pages with Sidekiq and Redis.

## Services

| Container | Role |
|-----------|------|
| `links-web` | Rails web server |
| `links-sidekiq` | Sidekiq worker |
| `links-redis` | Private Redis |

## Network dependencies

| Network | Purpose |
|---------|---------|
| `nginx-proxy-net` | Reverse proxy |
| `postgres-net` | Shared PostgreSQL |
| `cups-net` | CUPS printing integration |

## Configuration

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `IMAGE_VERSION` | Application image tag |
| `REDIS_IMAGE_VERSION` | Redis image tag |
| `DATABASE_URL` | PostgreSQL connection URL |
| `REDIS_URL` | Redis URL |
| `CUPS_SERVER` | CUPS server hostname:port |

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```
