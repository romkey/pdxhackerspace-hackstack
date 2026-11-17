# stable-diffusion-webui (experiment)

Stable Diffusion image generation web interface

## Configuration

### Environment Variables

Copy `.env.example` to `.env`. Compose reads **`GPU_COUNT`** from this file for GPU reservations (default **`1`** if unset); other variables are for the application as documented upstream.

```bash
cp .env.example .env
# Edit .env with your settings
```

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
```

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

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
