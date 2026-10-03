# music-assistant

[Music Assistant](https://music-assistant.io/) server for Home Assistant integration. Runs in host network mode for multicast discovery.

## Configuration

Copy `.env.example` to `.env` if you need to override image version or timezone:

```bash
cp .env.example .env
```

Application data is stored under `../../lib/music-assistant`.

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
