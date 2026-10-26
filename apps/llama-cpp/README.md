# llama-cpp

OpenAI-compatible local LLM inference server based on
[llama.cpp](https://github.com/ggml-org/llama.cpp). Runs GGUF-format models
on CPU or GPU and exposes them as an OpenAI API endpoint on `llama-net`,
making it usable by [openwebui](../openwebui/) and
[home-assistant](../home-assistant/) alongside [ollama](../ollama/).

## Choosing compose files

`docker-compose.yml` is hardware-neutral and runs the CPU image by itself. Pick
the hardware override with `COMPOSE_FILE` in `.env` (the `.env.example` lists every line):

| Hardware | `COMPOSE_FILE` | Image tag |
|----------|----------------|-----------|
| NVIDIA discrete GPUs (driver >= 570) | `docker-compose.yml:docker-compose.nvidia.yml` | `server-cuda` (CUDA 12.8) |
| NVIDIA DGX Spark (GB10) | `docker-compose.yml:docker-compose.nvidia.yml:docker-compose.spark.yml` | `server-cuda13` |
| NVIDIA Jetson Thor | `docker-compose.yml:docker-compose.jetson.yml` | `server-cuda13`, `nvidia` runtime |
| AMD Strix Halo / Strix Point | `docker-compose.yml:docker-compose.strix.yml` | `server-vulkan` |
| Intel Arc | `docker-compose.yml:docker-compose.arc.yml` | `server-intel` (SYCL) |
| CPU only | `docker-compose.yml` | `server` |

Notes:

- The GPU files default `LLAMA_ARG_N_GPU_LAYERS` to `999` (offload everything); set it in `.env` to override.
- `IMAGE_VERSION` is the full image tag and overrides the file's default. Leave it unset unless you want to pin a build (`server-cuda-b6500`) or switch backend within a file: `server-cuda13` on `nvidia.yml` (driver >= 580), `server-rocm` on `strix.yml`, `server-vulkan` on `arc.yml`.
- **Jetson Thor**: the toolkit runs in CSV mode there and rejects GPU reservations, so `jetson.yml` uses `runtime: nvidia` and replaces `nvidia.yml` rather than layering on it.
- **Strix**: Vulkan (RADV) is the most reliable and usually fastest llama.cpp backend on these APUs. For large models on Strix Halo, raise the GPU's share of system memory on the host (BIOS UMA setting and/or the `amdttm.pages_limit` kernel parameter).

## Models

Models are stored in `../../lib/llama-cpp/models/` on the host (mounted as
`/models` inside the container). llama.cpp uses **GGUF** format.

Download a model before starting the service, for example:

```bash
mkdir -p ../../lib/llama-cpp/models
curl -L -o ../../lib/llama-cpp/models/model.gguf \
  https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf
```

Then set `LLAMA_ARG_MODEL=/models/model.gguf` in `.env`.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description | Default |
|----------|-------------|---------|
| `LLAMA_ARG_MODEL` | Path to the GGUF model file inside the container | `/models/model.gguf` |
| `LLAMA_ARG_N_GPU_LAYERS` | Layers to offload to GPU (`0` = CPU only, `999` = all) | `999` in the GPU files |
| `LLAMA_ARG_CTX_SIZE` | Context window size in tokens | `4096` |
| `LLAMA_ARG_THREADS` | CPU threads to use | `4` |
| `LLAMA_ARG_HOST` | Bind address inside the container | `0.0.0.0` |
| `LLAMA_ARG_PORT` | Port inside the container | `8080` |
| `IMAGE_VERSION` | Full image tag, overrides the compose file's default (see above) | per file |

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml:docker-compose.nfs.yml
```

(use your hardware line, with `docker-compose.nfs.yml` last)

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

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

### Testing the API

```bash
curl http://llama-cpp:8080/v1/models
```

From outside the container network, use the host IP or reverse-proxy hostname.

## API compatibility

llama.cpp server implements the OpenAI API (`/v1/chat/completions`,
`/v1/completions`, `/v1/models`, `/v1/embeddings`). Configure openwebui to
point at `http://llama-cpp:8080` as an additional OpenAI-compatible endpoint.
