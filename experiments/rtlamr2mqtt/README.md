# rtlamr2mqtt

Smart meter reading via RTL-SDR to MQTT

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

### Config file

Copy the template into `config/` (tracked file is `config/rtlamr2mqtt.yaml.default`):

```bash
cp config/rtlamr2mqtt.yaml.default config/rtlamr2mqtt.yaml
# Edit config/rtlamr2mqtt.yaml — it is mounted at /etc/rtlamr2mqtt.yaml in the container
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
