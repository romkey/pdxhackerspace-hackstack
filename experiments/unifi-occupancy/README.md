# unifi-occupancy (experiment)

[unifi-occupancy](https://github.com/romkey/unifi-occupancy) publishes UniFi Protect detection state (motion, person, vehicle, animal and so on) per camera to MQTT, with Home Assistant discovery. It only passes along on/off detection state, never pictures. Optionally it writes daily HTML occupancy sheets and runs an hourly camera health check against a vision model.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

| Variable | Notes |
|----------|-------|
| `UNIFI_HOST` | The UniFi OS console (UDM / UNVR / Cloud Key) |
| `UNIFI_API_KEY` | UniFi OS → Settings → Admins & Users → your user → API Keys |
| `MQTT_HOST` / `MQTT_USERNAME` / `MQTT_PASSWORD` | `apps/mosquitto`, reached on `mosquitto-net` |

See the [project README](https://github.com/romkey/unifi-occupancy#configuration) for everything else.

### Camera health check (optional)

Set `CAMERA_HEALTH_ENABLED=true` and point `CAMERA_HEALTH_API_BASE_URL` at any OpenAI-compatible endpoint with a vision model. For a local model, uncomment the `llama` network in `docker-compose.yml`.

### Occupancy sheets (optional)

```bash
cp config/config.yaml.example config/config.yaml
```

The sheets are only written when `config/config.yaml` exists. They go to `../../lib/unifi-occupancy/www` as static HTML; the service doesn't serve them itself, so point a web server at that directory to view them.

### Data directories

The container runs as uid 10001:

```bash
mkdir -p ../../lib/unifi-occupancy/www ../../lib/unifi-occupancy/data
sudo chown -R 10001:10001 ../../lib/unifi-occupancy
```

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
