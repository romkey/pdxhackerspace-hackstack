# forgejo (experiment)

[Forgejo](https://forgejo.org/) is a self-hosted Git forge — repositories, issues, pull requests, releases, and CI (Forgejo Actions) — forked from Gitea. This stack runs the official **`codeberg.org/forgejo/forgejo`** image, uses the **shared PostgreSQL** service (`postgresql` on `postgres-net`), and keeps all state (config, repositories, LFS objects, avatars) on **`../../lib/forgejo`** mounted at `/data`.

Forgejo writes its configuration to `/data/gitea/conf/app.ini`, so unlike most apps here there is no `config/` directory: settings are driven from `.env` with `FORGEJO__<section>__<KEY>` variables and re-applied to `app.ini` on every start.

## Configuration

### 1. PostgreSQL database

Create a dedicated database and user with the shared cluster helper (from **`apps/postgresql`**):

```bash
../../apps/postgresql/bin/mkdb.sh forgejo
```

That creates **`forgejo_db`** owned by **`forgejo_user`** and prints a password. Put that password in **`.env`** as **`FORGEJO__database__PASSWD`**.

### 2. Environment

Copy `.env.example` to **`.env`** and set at least:

```bash
cp .env.example .env
```

| Variable | Notes |
|----------|-------|
| `FORGEJO__database__PASSWD` | Password from `mkdb.sh` |
| `FORGEJO__server__DOMAIN` / `ROOT_URL` | Public hostname served by `nginx-proxy-manager` |
| `USER_UID` / `USER_GID` | Host user that owns `../../lib/forgejo` |
| `IMAGE_VERSION` | Pin to a major version in production |

`FORGEJO__security__INSTALL_LOCK=true` skips the web installer — the first account you create becomes the site administrator, and `FORGEJO__service__DISABLE_REGISTRATION=true` keeps everyone else out until you invite them. Set `DISABLE_REGISTRATION=false` briefly to create that first account, or create it from the CLI (see below).

### 3. Data directory

```bash
mkdir -p ../../lib/forgejo
sudo chown 1000:1000 ../../lib/forgejo   # match USER_UID/USER_GID
```

### 4. Reverse proxy

Point `nginx-proxy-manager` at **`forgejo:3000`**. Raise the proxy's `client_max_body_size` (e.g. `512m`) if you expect large pushes or LFS uploads.

### 5. Git over SSH (optional)

HTTPS clones work through the proxy with no extra setup. For `ssh://` clones, uncomment the `2222:22` mapping in `docker-compose.yml` and set in `.env`:

```
FORGEJO__server__START_SSH_SERVER=true
FORGEJO__server__SSH_PORT=2222
```

`SSH_PORT` must match the published host port — it is what clone URLs advertise. Note that published Docker ports bypass `ufw` (see [Contributing](../../docs/contributing.md)).

## Networks

- **`postgres-net`** — database (`postgresql` hostname)
- **`nginx-proxy-net`** — reverse proxy to container port **3000**

## Healthcheck

`wget` to **`http://127.0.0.1:3000/api/healthz`** inside the container. The `start_period` is 60s because the first start runs database migrations.

## Usage

### Start

```bash
docker compose up -d
```

### Stop

```bash
docker compose down
```

### Logs

```bash
docker compose logs -f
```

### Create an administrator from the CLI

```bash
docker compose exec -u git forgejo forgejo admin user create \
  --admin --username admin --email admin@example.org --random-password
```

### Upgrades

Watchtower will pull new images. Migrations run automatically on start, but **major** version jumps should be done one at a time with a fresh backup — pin `IMAGE_VERSION` to a major version to keep Watchtower inside a release line.

## Backup

- **PostgreSQL:** `forgejo_db` is dumped by `db-backup` via `BACKUP_DATABASE_URLS` in `.env` (added by `mkdb.sh`).
- **Files:** **`../../lib/forgejo`** (repositories, LFS, avatars, `app.ini`) is backed up by `backrest`.
