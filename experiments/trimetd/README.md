# trimetd

Daemon that polls the [TriMet](https://trimet.org/) API for real-time transit
data and publishes it to the MQTT broker.

Image source: [romkey/pdxhackstack-trimetd](https://github.com/romkey/pdxhackerspace-hackstack-trimetd)

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `TRIMET_API_KEY` | TriMet developer API key (required) — get one at https://developer.trimet.org/ |
| `MQTT_HOST` | MQTT broker hostname | 
| `MQTT_PORT` | MQTT broker port |
| `MQTT_USER` | MQTT username (if auth enabled) |
| `MQTT_PASSWORD` | MQTT password (if auth enabled) |
| `IMAGE_VERSION` | Docker image tag (optional, defaults to `latest`) |

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
