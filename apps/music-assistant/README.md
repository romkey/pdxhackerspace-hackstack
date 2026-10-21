# music-assistant

[Music Assistant](https://music-assistant.io/) server for Home Assistant integration. Runs in host network mode for multicast discovery.

## Configuration

Copy `.env.example` to `.env` if you need to override image version or timezone:

```bash
cp .env.example .env
```

Application data is stored under `../../lib/music-assistant`.

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

## Troubleshooting

### "No buffer space available"

See [Container does not start successfully](https://github.com/music-assistant/hass-music-assistant/issues/1804).

As root create `/etc/sysctl.d/99-music-assistant.conf` on your host server with these lines:

```
# For Music Assistant
net.ipv4.igmp_max_memberships = 50
net.ipv4.igmp_max_msf = 30
```

Then run these commands to activate the settings immediately without reboot:

```bash
sysctl -w net.ipv4.igmp_max_memberships=50
sysctl -w net.ipv4.igmp_max_msf=30
```
