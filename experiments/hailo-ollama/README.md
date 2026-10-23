# hailo-ollama (experiment)

[Hailo-Ollama](https://github.com/hailo-ai/hailo_model_zoo_genai) is an Ollama-compatible API server that runs LLMs on a Hailo-10H accelerator — for us, a Raspberry Pi 5 with the **Raspberry Pi AI HAT+ 2**. Models are Hailo's pre-compiled HEF files from the GenAI Model Zoo, not GGUF, so only the models Hailo publishes will work.

## Requirements

- Raspberry Pi 5 with an AI HAT+ 2 (Hailo-10H), 64-bit Raspberry Pi OS
- The Hailo-10H kernel driver loaded on the host so the device node exists (Hailo's docs use **`/dev/h1x-0`**)
- Hailo's pre-built Docker image (see below)

## Docker image

Hailo does not publish this image to Docker Hub or GHCR. Download the HailoRT Docker zip from the [Hailo Developer Zone](https://hailo.ai/developer-zone/) (free account required), copy it to the Pi, and load it:

```bash
unzip hailort_<ver>_docker.zip
docker load -i hailo_docker_hailort_ub2204_<ver>.tar
docker images | grep hailo
```

Put the loaded tag in **`IMAGE_VERSION`**. The compose file sets **`pull_policy: never`**, so Compose won't try to pull the image from a registry. Make sure you download the **arm64** build. The upstream example image is Ubuntu 22.04-based, and an amd64-only image won't run on the Pi.

## Configuration

### Environment Variables

```bash
cp .env.example .env
# Edit .env with your settings
```

| Variable | Default | Purpose |
|---|---|---|
| `IMAGE_VERSION` | (required) | Tag of the image loaded with `docker load` |
| `IMAGE_NAME` | `hailo_docker_hailort_ub2204` | Image repository name, if Hailo renames it |
| `HAILO_DEVICE` | `/dev/h1x-0` | Host device node passed into the container |
| `OLLAMA_HOST` | `0.0.0.0:8000` | Server bind address inside the container |
| `HAILO_OLLAMA_VDEVICE_GROUP_ID` | unset | Set (e.g. `SHARED`) to share the Hailo device with other HailoRT apps |

Persistent data: **`../../lib/hailo-ollama/models/blob`** (mounted at **`/usr/share/hailo-ollama/models/blob`**). Downloaded models live here.

## Networks

- **`nginx-proxy-net`** — reverse proxy to the API on **`:8000`**. Uncomment **`ports`** to expose it directly.

## Healthcheck

TCP probe of port **8000** via bash, since we don't know whether the image includes `curl`. Upstream has no dedicated health endpoint. **`GET /api/version`** is the closest.

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

### Models

```bash
curl http://localhost:8000/hailo/v1/list                                   # available to download
curl http://localhost:8000/api/pull -d '{"model": "qwen2:1.5b"}'                  # download one
curl http://localhost:8000/api/tags                                         # installed
curl http://localhost:8000/api/chat -d '{"model": "qwen2:1.5b", "messages": [{"role": "user", "content": "hi"}]}'
```

Clients such as Open WebUI or `llama-router` can use it as an Ollama backend at `http://hailo-ollama:8000`. It listens on port 8000, not Ollama's usual 11434.
