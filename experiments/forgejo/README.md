# forgejo (experiment)

[Forgejo](https://forgejo.org/) is a self-hosted Git forge — repositories, issues, pull requests, releases, and CI (Forgejo Actions) — forked from Gitea. This stack runs the official **`codeberg.org/forgejo/forgejo`** image, uses the **shared PostgreSQL** service (`postgresql` on `postgres-net`), and keeps all state (config, repositories, LFS objects, avatars) on **`../../lib/forgejo`** mounted at `/data`.

Forgejo writes its configuration to `/data/gitea/conf/app.ini`, so unlike most apps here there is no `config/` directory: settings are driven from `.env` with `FORGEJO__<section>__<KEY>` variables and re-applied to `app.ini` on every start. `/data` can optionally live on an NFS share instead of the local bind mount — see [`/data` over NFS](#4-data-over-nfs-optional).

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

### 4. `/data` over NFS (optional)

To keep repositories on a NAS instead of the local `../../lib/forgejo` bind mount, use the `docker-compose.nfs.yml` override. Set in **`.env`**:

```
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
FORGEJO_NFS_HOST=nas.example.org
FORGEJO_NFS_PATH=/export/forgejo
NFS_MOUNT_OPTS=nfsvers=4,hard
```

`COMPOSE_FILE` is read by `docker compose` itself, so `up`, `down` and `logs` keep working unchanged. If you would rather not set it, pass both files instead:

```bash
docker compose -f docker-compose.yml -f docker-compose.nfs.yml up -d
```

Notes:

- The export must be writable by **`USER_UID`/`USER_GID`**. With `root_squash` on the server, either map that uid or export with `no_root_squash` only if you understand the exposure.
- Use **`hard`**, not `soft`: a soft mount turns a server hiccup into write errors inside live repositories. Forgejo's database is PostgreSQL here, so the usual "no SQLite on NFS" warning does not apply, but Git object writes still want reliable semantics.
- Docker mounts the share when the volume is first created. If the NFS server is unreachable at that point the container will not start; `docker volume rm forgejo_forgejo_data` after fixing it, so the mount is retried.
- **Backups:** `backrest` backs up `../../lib/forgejo`, which is now empty. Back up the share on the NAS side instead, or point `backrest` at the same export.

### 5. Reverse proxy

Point `nginx-proxy-manager` at **`forgejo:3000`**. Raise the proxy's `client_max_body_size` (e.g. `512m`) if you expect large pushes or LFS uploads.

### 6. Git over SSH (optional)

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
- **Files:** **`../../lib/forgejo`** (repositories, LFS, avatars, `app.ini`) is backed up by `backrest`. If you moved `/data` to NFS, back up the share on the NAS side instead — `backrest` will find nothing under `lib/forgejo`.
