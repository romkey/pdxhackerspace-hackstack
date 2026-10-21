# tranquil (experiment)

[Tranquil PDS](https://tangled.org/tranquil.farm/tranquil-pds) is a community AT Protocol Personal Data Server (PDS). It is a superset of Bluesky's reference PDS, with passkeys/2FA, an admin UI, granular OAuth scopes, and optional SSO.

This stack runs the **`atcr.io/tranquil.farm/tranquil-pds`** image, uses the **shared PostgreSQL** service (`postgresql` on `postgres-net`), and stores blobs under **`../../lib/tranquil`**.

For the Bluesky reference PDS instead, see **`experiments/pds`**.

## Configuration

### 1. PostgreSQL database

Create a dedicated database and user with the shared cluster helper (from **`apps/postgresql`**):

```bash
../../apps/postgresql/bin/mkdb.sh tranquil
```

That creates **`tranquil_db`** owned by **`tranquil_user`** and prints a password. Put the connection URL in **`.env`** as **`DATABASE_URL`** (see `.env.example`).

### 2. Environment

```bash
cp .env.example .env
# Edit .env: DATABASE_URL, secrets, PDS_HOSTNAME, handle domains
```

Generate secrets with `openssl rand -base64 48` for **`JWT_SECRET`**, **`DPOP_SECRET`**, and **`MASTER_KEY`**.

The registry image may require login: `podman login atcr.io` (or `docker login atcr.io`).

### 3. Config file

Non-secret defaults live in **`config/config.toml.default`**. Copy and adjust:

```bash
cp config/config.toml.default config/config.toml
mkdir -p ../../lib/tranquil/blobs ../../lib/tranquil/store
```

Secrets and hostname settings should stay in **`.env`**; they override the config file.

## Networks

- **`postgres-net`** — database (`postgresql` hostname)
- **`nginx-proxy-net`** — reverse proxy to container port **3000**

## Healthcheck

Runs **`tranquil-pds healthcheck`** inside the container.

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
```

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

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

### Backup

- **PostgreSQL:** include `tranquil_db` in normal DB backups (`BACKUP_DATABASE_URLS` from `mkdb.sh`).
- **Blobs:** back up **`../../lib/tranquil/blobs`** (and **`../../lib/tranquil/store`** if you switch to the experimental tranquil-store repo backend).
