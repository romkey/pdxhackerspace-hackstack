# llama-router (experiment)

[llama-router](https://github.com/romkey/llama-router) routes requests across multiple Ollama and llama.cpp backends and optional OCI model cache.

## Configuration

Copy **`.env.example`** to **`.env`**. Set **`LLAMA_ROUTER_CACHE_EXTERNAL_HOST`** to a hostname or IP your Ollama backends use to reach the cache (see upstream README). Use **`IMAGE_VERSION`** to pin the image tag.

Persistent data: **`../../lib/llama-router`** (mounted at **`/app/data`**).

## Networks

- **`nginx-proxy-net`** — reverse proxy to dashboard (**`:80`**) and/or APIs if you publish ports or use a proxy container.

## Healthcheck

**`GET /health`** on **`127.0.0.1:80`** (dashboard), then **`:11434`**, then **`:8080`**, via **`python3`** (the image is `python:3.12-slim` and does not include `curl`). Port **9200** is the OCI cache registry only—not used for liveness.

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

## Ports (optional)

Uncomment **`ports`** in **`docker-compose.yml`** only if needed. Defaults inside the image: dashboard **80**, llama.cpp/OpenAI API **8080**, Ollama API **11434**, registry cache **9200**.
