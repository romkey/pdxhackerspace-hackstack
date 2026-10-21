# unified-audio (experiment)

AirPlay, Sendspin, Spotify Connect, DLNA, and optional Bluetooth/MQTT in one container from [`ghcr.io/romkey/hackstack-sendspin-shairport-sync`](https://github.com/romkey/hackstack-sendspin-shairport-sync).

**Host networking is required** for AirPlay 2 mDNS and fixed UDP ports; bridge mode will not work.

## Configuration

```bash
cp .env.example .env
```

See `.env.example` for audio device, enabled services, MQTT, and optional Bluetooth/Spotify/DLNA settings. Overrides can live under `config/` (see comments in compose).

| Variable | Notes |
|----------|-------|
| `IMAGE_VERSION` | Published image tag (default `latest`) |
| `AIRPLAY_NAME` | Display name on the LAN |
| `ALSA_PCM` | ALSA output device |

## LAN macvlan (optional)

By default this app uses bridge and/or host networking in `docker-compose.yml`. For a **dedicated LAN IPv4 and MAC** on the shared **`lan_macvlan`** network, set in **`.env`** (see **`.env.example`** and [docs/macvlan.md](../../docs/macvlan.md)):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml
```

Assign a unique **`IPV4_ADDRESS`** and **`LAN_MAC_ADDRESS`** per app. Run **`../../bin/create-macvlan.sh`** from the repo root once (see [docs/macvlan.md](../../docs/macvlan.md)).


## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```
