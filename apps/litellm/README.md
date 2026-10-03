# litellm

[LiteLLM](https://docs.litellm.ai/) proxy for unified LLM API access with Redis caching and PostgreSQL storage.

## Services

| Container | Role |
|-----------|------|
| `litellm` | LiteLLM proxy (port 4000, behind reverse proxy) |
| `litellm-redis` | Private Redis |

## Network dependencies

| Network | Purpose |
|---------|---------|
| `nginx-proxy-net` | Reverse proxy |
| `postgres-net` | Shared PostgreSQL |
| `postfix-net` | Outbound email (optional) |

Edit `config/config.yaml` for model providers and routing. Environment variables in `.env` supplement compose settings.

## Configuration

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `IMAGE_VERSION` | LiteLLM image tag (default `main-stable`) |
| `REDIS_IMAGE_VERSION` | Redis image tag |
| `REDIS_URL` | Redis connection URL |
| `DATABASE_URL` | PostgreSQL connection URL |

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```
