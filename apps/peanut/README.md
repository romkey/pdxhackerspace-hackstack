# peanut

Web UI for Network UPS Tools (NUT)

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

### Configuration Files

Configuration files are stored in the `config/` directory.

## Healthcheck

The image defines a working check: `node healthcheck.mjs` hits `http://127.0.0.1:$WEB_PORT/api/ping`. Do not use `wget`/`curl` probes—the runtime image is minimal and may not include them.

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
