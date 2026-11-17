# library (experiment)

[PDX Hackerspace Library](https://github.com/pdxhackerspace/library) is a Rails app for tracking the space's physical books and their loans, with ISBN metadata lookup, NFC tag writing and an optional catalog feed for search indexers.

## Services

| Service | Purpose |
|---------|---------|
| `web` (`library`) | Rails app on port 3000 |
| `sidekiq` (`library-sidekiq`) | Background jobs (metadata lookups, mail) |
| `redis` (`library-redis`) | Sidekiq queue and Rails cache, on its own `library-redis-net` |

Both Rails containers run pending migrations on start.

## Configuration

### Database

Create the database with the shared cluster helper:

```bash
../../apps/postgresql/bin/mkdb.sh library
```

That creates `library_db` owned by `library_user` and prints a password. Put it in `DATABASE_URL` in `.env`.

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

| Variable | Notes |
|----------|-------|
| `SECRET_KEY_BASE` | `openssl rand -hex 64` |
| `DATABASE_URL` | Password from `mkdb.sh` |
| `APP_BASE_URL` / `APP_HOST` | Public URL served by nginx-proxy-manager |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Local admin, created by `db:seed` |
| `OIDC_*` | Optional authentik login; register `<APP_BASE_URL>/auth/oidc/callback` as the redirect URI |
| `GUEST_SUBNET_CIDRS` | Optional: subnets that can browse without signing in |

See the [project README](https://github.com/pdxhackerspace/library#readme) for the rest.

### First run

The local admin account is created by `db:seed`, which isn't run automatically in production:

```bash
docker compose exec web ./bin/rails db:seed
```

### Data directories

The containers run as the image's `rails` user (uid 1000):

```bash
mkdir -p ../../lib/library/storage ../../lib/library/redis
sudo chown 1000:1000 ../../lib/library/storage
```

Point nginx-proxy-manager at `library:3000`.

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
