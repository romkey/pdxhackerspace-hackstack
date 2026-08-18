# gunky

Rails web application with Sidekiq and private Redis.

## Services

| Container | Role |
|-----------|------|
| `gunky` | Rails web server |
| `sidekiq` | Sidekiq background worker |
| `redis` | Private Redis (internal `gunky-redis-net`) |

## Network dependencies

| Network | Purpose |
|---------|---------|
| `nginx-proxy-net` | Reverse proxy |
| `postgres-net` | Shared PostgreSQL |

Create the database with `../postgresql/bin/mkdb.sh gunky` from this directory.

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `IMAGE_VERSION` | Application image tag |
| `REDIS_IMAGE_VERSION` | Redis image tag |
| `SECRET_KEY_BASE` | Rails secret — `openssl rand -hex 64` |
| `DATABASE_URL` | PostgreSQL connection URL |
| `REDIS_URL` | Redis URL (default points at internal redis service) |

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```
