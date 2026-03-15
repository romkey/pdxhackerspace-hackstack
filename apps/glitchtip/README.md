# glitchtip

[GlitchTip](https://glitchtip.com) is a Sentry-compatible self-hosted error
tracking and uptime monitoring platform.  Unlike Sentry, it runs with only
PostgreSQL and Redis — no ClickHouse, Kafka, or Snuba required.

## Services

| Service | Image | Role |
|---|---|---|
| `glitchtip` | `glitchtip/glitchtip` | Django web app + API |
| `glitchtip-worker` | `glitchtip/glitchtip` | Celery worker + beat scheduler |
| `glitchtip-redis` | `redis` | Celery broker and cache |
| `glitchtip-migrate` | `glitchtip/glitchtip` | One-shot database migration runner |

## Networks

| Network alias | Actual network | Purpose |
|---|---|---|
| `db` | `postgres-net` | Shared PostgreSQL |
| `proxy` | `nginx-proxy-net` | Reverse proxy (nginx-proxy-manager) |
| `mail` | `postfix-net` | Outbound email via shared postfix |
| `redis` | `glitchtip-redis-net` | Internal Redis (glitchtip-redis only) |

## First-time setup

### 1. Create the database

Connect to the shared PostgreSQL instance:

```sql
CREATE USER glitchtip_user WITH PASSWORD 'your-password';
CREATE DATABASE glitchtip_db OWNER glitchtip_user;
```

### 2. Configure environment

```sh
cp .env.example .env
```

Edit `.env` and fill in at minimum:

- `SECRET_KEY` — generate with:
  ```sh
  python3 -c "import secrets; print(secrets.token_hex(50))"
  ```
- `DATABASE_URL` — update the password to match what you set above
- `GLITCHTIP_DOMAIN` — the public URL (e.g. `https://glitchtip.example.com`)
- `DEFAULT_FROM_EMAIL` — sender address for alerts and invites

### 3. Run migrations

```sh
docker compose run --rm glitchtip-migrate
```

### 4. Start

```sh
docker compose up -d
```

The `glitchtip-migrate` container will also run automatically on every
`docker compose up`; Django migrations are idempotent so this is safe.

### 5. Create the first superuser

```sh
docker compose exec glitchtip ./manage.py createsuperuser
```

Then log in at your `GLITCHTIP_DOMAIN` and create an organization and project.

## SDK configuration

Point your Sentry SDK at GlitchTip by replacing the DSN host.  GlitchTip
issues DSNs in the same format as Sentry — copy the DSN from the project
settings page.

## Reverse proxy

Configure nginx-proxy-manager to proxy `glitchtip.example.com` → `glitchtip:8000`.

## Stopping safely

```sh
docker compose down
```
