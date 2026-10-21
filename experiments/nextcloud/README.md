# nextcloud (experiment)

[Nextcloud](https://nextcloud.com/) file sync and collaboration, using the official Docker image with the shared PostgreSQL service (`postgres-net`).

## Configuration

Copy `.env.example` to `.env` and set database credentials, admin user, trusted domains, and optional `IMAGE_VERSION`.

Configuration reference: [Nextcloud Docker environment variables](https://github.com/nextcloud/docker#auto-configuration-via-environment-variables).

## Networks

- **`nginx-proxy-net`** — reverse proxy to the web container (port **80** inside the container unless you change it)
- **`postgres-net`** — PostgreSQL as `postgresql:5432`

## Healthcheck

`curl` to **`http://127.0.0.1/status.php`** inside the container. **HTTP 503** usually means maintenance mode, upgrade in progress, or DB/config issues—not a bad healthcheck definition.

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
```

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

Persistent data: **`../../lib/nextcloud`**.
