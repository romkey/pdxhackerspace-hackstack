# comfy-ui (experiment)

ComfyUI on the [`ghcr.io/romkey/comfyui-docker`](https://github.com/romkey/comfyui-docker) image, with GPU reservations and shared model paths for the LLM stack.

Runtime state and models live under `../../lib/comfyui`. Model layout for ComfyUI is described in `config/extra_model_paths.yaml`.

## Configuration

```bash
cp .env.example .env
mkdir -p ../../lib/comfyui/models
```

| Variable | Notes |
|----------|-------|
| `IMAGE_VERSION` | Image tag (default `latest`) |
| `GPU_COUNT` | GPUs reserved in compose (default `1`) |
| `RESERVE_VRAM_GB` | VRAM left for co-resident vLLM |
| `CLI_ARGS` | ComfyUI startup flags |
| `HF_TOKEN` | Optional Hugging Face token for gated models |

## Networks

- **`nginx-proxy-net`** — reverse proxy to port **8188**
- **`llama-net`** — same LLM network as `apps/vllm`

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
```

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```
