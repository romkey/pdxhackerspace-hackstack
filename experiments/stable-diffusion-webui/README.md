# stable-diffusion-webui

Stable Diffusion image generation web interface

## Configuration

### Environment Variables

Copy `.env.example` to `.env`. Compose reads **`GPU_COUNT`** from this file for GPU reservations (default **`1`** if unset); other variables are for the application as documented upstream.

```bash
cp .env.example .env
# Edit .env with your settings
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
