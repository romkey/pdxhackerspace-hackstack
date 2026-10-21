# jellyfin

Media server for streaming movies, TV, and music

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

### Configuration Files

Configuration files are stored in the `config/` directory.

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
```

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

## LAN macvlan (optional)

By default this app uses bridge and/or host networking in `docker-compose.yml`. For a **dedicated LAN IPv4 and MAC** on the shared **`lan_macvlan`** network, set in **`.env`** (see **`.env.example`** and [docs/macvlan.md](../../docs/macvlan.md)):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml
```

Assign a unique **`IPV4_ADDRESS`** and **`LAN_MAC_ADDRESS`** per app. Run **`../../bin/create-macvlan.sh`** from the repo root once (see [docs/macvlan.md](../../docs/macvlan.md)).


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
