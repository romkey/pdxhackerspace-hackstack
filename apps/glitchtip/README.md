# glitchtip

[GlitchTip](https://glitchtip.com) is a Sentry-compatible self-hosted error
tracking and uptime monitoring platform. Unlike Sentry, it runs with only
PostgreSQL and Redis — no ClickHouse, Kafka, or Snuba required. Use this
stack instead of the removed `apps/sentry/` stub.

## Services

| Service | Image | Role |
|---|---|---|
| `glitchtip` | `glitchtip/glitchtip` | Django web app + API |
| `glitchtip-worker` | `glitchtip/glitchtip` | Celery worker + beat scheduler |
| `glitchtip-redis` | `redis` | Celery broker and cache (no AOF; `save 900 1` only—see [redis-persistence-hackstack.md](../../docs/redis-persistence-hackstack.md)) |
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

## SSO (Authentik OpenID Connect)

GlitchTip supports OIDC login through [django-allauth](https://docs.allauth.org/).
This stack configures providers from a YAML file rather than Django Admin so
credentials stay in version-controlled config.

### 1. Create an Authentik application

In Authentik, create an **OAuth2/OpenID Connect** provider and application.
Note the application slug, client ID, and client secret.

Add a **Strict** redirect URI of type **Authorization**:

```text
https://glitchtip.example.com/accounts/oidc/authentik/login/callback/
```

Replace the hostname with your `GLITCHTIP_DOMAIN`. If you change `provider_id`
in the YAML below, update the path segment after `/oidc/` to match.

See the [Authentik integration guide](https://integrations.goauthentik.io/monitoring/glitchtip/)
for details.

### 2. Configure GlitchTip

Copy the example provider config and fill in your Authentik values:

```sh
cp config/social-providers.yaml.example config/social-providers.yaml
```

Edit `config/social-providers.yaml` — set `client_id`, `secret`, and
`server_url` (typically `https://auth.example.com/application/o/<slug>/`).

Uncomment and set in `.env`:

```sh
SOCIALACCOUNT_PROVIDERS_CONFIG_PATH=/code/config/social-providers.yaml
ENABLE_USER_REGISTRATION=False
ENABLE_SOCIAL_APPS_USER_REGISTRATION=False
```

Restart GlitchTip after changing either file:

```sh
docker compose up -d
```

With `ENABLE_SOCIAL_APPS_USER_REGISTRATION=False`, only users who already
exist in GlitchTip can sign in through Authentik. Create the first accounts
with `./manage.py createsuperuser` or organization invitations before
enabling SSO.

To link Authentik to an existing GlitchTip account, sign in locally, open
**Profile**, and use **Add Account** under Social Auth Accounts.

## Upgrading

Pulling a new image does not run database migrations by itself. After bumping
`IMAGE_VERSION` (or pulling `latest`), apply schema changes before relying on
the new version:

```sh
docker compose pull
docker compose run --rm glitchtip-migrate
docker compose up -d
```

The `glitchtip-migrate` service is one-shot (`restart: "no"`) and is not
started by a normal `docker compose up -d`. Migrations are idempotent, so
re-running the command is safe.

Back up the database before upgrading. Read the
[GlitchTip release notes](https://gitlab.com/glitchtip/glitchtip-backend/-/releases)
for breaking changes between major versions.

## Stopping safely

```sh
docker compose down
```
