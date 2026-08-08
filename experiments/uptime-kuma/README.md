# uptime-kuma (experiment)

[Uptime Kuma](https://github.com/louislam/uptime-kuma) is a self-hosted uptime monitor and status page. It probes HTTP(S), TCP, ping, DNS, MQTT and Docker container targets on a schedule, keeps history, and sends notifications (email, Matrix, MQTT, ntfy, webhooks, and many more) when something goes down.

This overlaps with **`apps/statping`**; it is here as an experiment so the two can be compared before either becomes part of the core stack.

## Prerequisites

**`nginx-proxy-net`** (from `apps/nginx-proxy-manager`) must exist.

Create the data directory on the host:

```bash
mkdir -p ../../lib/uptime-kuma
```

## Configuration

```bash
cp .env.example .env
```

**`IMAGE_VERSION`** defaults to **`2`**. Do not use `latest` — upstream deprecated it and it still resolves to the 1.x line.

Everything else (monitors, notifications, status pages, the admin account) is configured through the web UI on first run, not through files in this directory.

### Database

**PostgreSQL is not an option here.** Uptime Kuma supports only SQLite and MariaDB/MySQL; anything else is rejected at startup with `Unknown Database type`. MariaDB support is what shipped in 2.0, and Postgres was deferred to a future major release because it needs parts of the query layer rewritten — see [PR #3748](https://github.com/louislam/uptime-kuma/pull/3748) (closed) and [issue #959](https://github.com/louislam/uptime-kuma/issues/959) (open, no target release). If a Postgres-backed monitor is a requirement, **`apps/statping`** already uses `postgres-net`.

By default Uptime Kuma keeps everything in SQLite under **`../../lib/uptime-kuma`**, which is fine for a few dozen monitors and needs no setup.

To use the shared MariaDB instead, do it **before** the first run — Uptime Kuma cannot switch backends after setup:

```bash
../../apps/mariadb/bin/mkdb.sh uptimekuma
```

Then uncomment the **`UPTIME_KUMA_DB_*`** variables in `.env` (filling in the generated password) and the **`mariadb`** network in `docker-compose.yml`.

## Reaching the services you monitor

Uptime Kuma only sees networks its container has joined. Anything reachable from the host by IP or public DNS works out of the box, but to monitor another stack's container by name (for example `http://wiki:3000`), uncomment that network in both the service's `networks:` list and the top-level `networks:` block in `docker-compose.yml`.

**Docker Container** monitors additionally need the Docker socket; the bind mount is commented out in `docker-compose.yml` because any container with the socket can control the whole Docker daemon.

## First run

1. Point your reverse proxy at **`uptime-kuma:3001`** (or publish **`3001`** temporarily — see the commented **`ports`** in `docker-compose.yml`).

2. Open the URL and create the admin account. There is no default login, and the setup screen is reachable by anyone until you do.

If the UI loads but the dashboard stays disconnected, the websocket origin check is probably rejecting the proxied hostname; see **`UPTIME_KUMA_WS_ORIGIN_CHECK`** in `.env.example`.

## Networks

- **`nginx-proxy-net`** — browser access via proxy
- optional, commented out — `mariadb-net`, `postgres-net`, `mosquitto-net`, `hass-net`, `influxdb-net` for monitoring those services by container name

## Usage

From the repo root:

```bash
bin/install-experimental.sh        # copy .env, set TZ
bin/install-experimental.sh start  # after the proxy is up
```

Or manually:

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

## Healthcheck

The image ships **`/app/extra/healthcheck`**, which connects to the server on its configured port; `docker-compose.yml` runs it every 30s.

## Backup

- SQLite: back up **`../../lib/uptime-kuma`** (`kuma.db` plus its WAL files and the uploaded status page icons).
- MariaDB: **`mkdb.sh`** adds **`BACKUP_DATABASE_URLS`** to `.env` so `apps/db-backup` picks the database up; still back up **`../../lib/uptime-kuma`** for uploads.
