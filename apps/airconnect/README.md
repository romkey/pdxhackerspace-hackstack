# airconnect

AirPlay to Chromecast/UPnP bridge so members with Apple devices can AirPlay to Chromecasts around the space.

Runs in host network mode for discovery.

## Configuration

Copy `.env.example` to `.env` and configure device names and targets:

```bash
cp .env.example .env
```

Configuration files live under `config/`.

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
