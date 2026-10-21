# home-assistant

Home automation platform.

## Configuration

Copy `.env.example` to `.env`. By default the container uses bridge networks (`hass-net`, `nginx-proxy-net`, `mosquitto-net`, etc.) only.

## LAN macvlan (optional)

For a **real LAN address** (mDNS, local integrations, voice SIP, and similar), create the shared network once from the repo root, then enable the macvlan overlay:

```bash
../../bin/create-macvlan.sh
```

Set in **`.env`** (see **`.env.example`** and [docs/macvlan.md](../../docs/macvlan.md)):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml
```

Keep **`hass-net`** and the other bridge networks enabled in the base compose file so HA can still reach piper, MQTT, and the reverse proxy by Docker name.

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```
