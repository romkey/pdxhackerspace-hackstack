# backrest

Web UI for [Restic](https://restic.net/) backup management, provided by
[garethgeorge/backrest](https://github.com/garethgeorge/backrest).

Backrest lets you configure, run, and monitor Restic backup jobs through a
browser-based interface. It stores its own database and the Restic binary under
`../../lib/backrest` and is accessible via the reverse proxy.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description | Default |
|----------|-------------|---------|
| `BACKREST_CACHE_PATH` | Host path for the Restic cache (speeds up operations significantly) | _(required)_ |
| `BACKREST_REPOS_PATH` | Host path where Restic repositories are stored | _(required)_ |
| `BACKREST_USERDATA_PATH` | Host path mounted as `/userdata` inside the container for backup sources | `/opt` |
| `BACKREST_USERETC_PATH` | Host path mounted as `/useretc` inside the container | `/etc` |
| `BACKREST_USERHOME_PATH` | Host path mounted as `/userhome` inside the container | `/home` |
| `BACKREST_DATA` | Path inside container for backrest database and Restic binary | `/data` |
| `BACKREST_CONFIG` | Path inside container for the backrest config file | `/config/config.json` |
| `XDG_CACHE_HOME` | Cache directory path inside the container | `/cache` |
| `IMAGE_VERSION` | Docker image tag to use | `latest` |

`BACKREST_CACHE_PATH` and `BACKREST_REPOS_PATH` are required — backrest will
fail to start if these are not set.

### Configuration Files

Backrest's own configuration (backup jobs, schedules, credentials) is stored in
`config/config.json` and managed through the web UI. No manual editing is
normally needed.

### Restic cache and repositories

By default, **`BACKREST_CACHE_PATH`** and **`BACKREST_REPOS_PATH`** in `.env` are bind-mounted as `/cache` and `/repos`. For NAS storage instead, use **`docker-compose.nfs.yml`** (see below).

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
