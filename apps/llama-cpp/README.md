# llama-cpp

OpenAI-compatible local LLM inference server based on
[llama.cpp](https://github.com/ggml-org/llama.cpp). Runs GGUF-format models
on CPU or GPU and exposes them as an OpenAI API endpoint on `llama-net` (or on
a published host port; see [Reaching the service](#reaching-the-service)),
making it usable by [openwebui](../openwebui/) and
[home-assistant](../home-assistant/) alongside [ollama](../ollama/).

## Choosing compose files

`docker-compose.yml` is hardware-neutral and runs the CPU image by itself. Compose assembles `COMPOSE_FILE` in `.env` from three settings: `COMPOSE_HARDWARE` (below), `COMPOSE_ACCESS` (see [Reaching the service](#reaching-the-service)) and `COMPOSE_STORAGE` (NFS). Set those and leave the `COMPOSE_FILE` line alone; plain `docker compose up -d` then uses all three.

Pick the hardware with `COMPOSE_HARDWARE` (the `.env.example` lists every line):

| Hardware | `COMPOSE_HARDWARE` | Image tag |
|----------|----------------|-----------|
| NVIDIA discrete GPUs (driver >= 570) | `:docker-compose.nvidia.yml` | `server-cuda` (CUDA 12.8) |
| NVIDIA DGX Spark (GB10) | `:docker-compose.nvidia.yml:docker-compose.spark.yml` | `server-cuda13` |
| NVIDIA Jetson Thor | `:docker-compose.jetson.yml` | `server-cuda13`, `nvidia` runtime |
| AMD Strix Halo / Strix Point | `:docker-compose.strix.yml` | `server-vulkan` |
| Intel Arc | `:docker-compose.arc.yml` | `server-intel` (SYCL) |
| CPU only | *(empty)* | `server` |

Notes:

- GPU layers and context size are fitted to free device memory automatically (`--fit`, on by default). Setting `LLAMA_ARG_N_GPU_LAYERS` or `LLAMA_ARG_CTX_SIZE` pins that value and turns fitting off for it.
- `.env.example` has tuned, commented-out settings for each platform; uncomment the block for your hardware.
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

Alternatively, let llama.cpp download it: set `LLAMA_ARG_HF_REPO=<user>/<repo>[:quant]`
instead of `LLAMA_ARG_MODEL`, and `HF_HUB_CACHE=/models/hf-cache` so the download
lands on the models volume and survives container recreation. `HF_ENDPOINT` points
it at a Hugging Face mirror; see `.env.example`.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description | Default |
|----------|-------------|---------|
| `LLAMA_ARG_MODEL` | Path to the GGUF model file inside the container | `/models/model.gguf` |
| `LLAMA_ARG_N_GPU_LAYERS` | Layers to offload to GPU (`0` = CPU only, `999` = all) | auto (fit to free memory) |
| `LLAMA_ARG_CTX_SIZE` | Context window size in tokens | `4096` |
| `LLAMA_ARG_THREADS` | CPU threads to use | all cores |
| `LLAMA_ARG_HOST` | Bind address inside the container | `0.0.0.0` |
| `LLAMA_ARG_PORT` | Port inside the container | `8080` |
| `IMAGE_VERSION` | Full image tag, overrides the compose file's default (see above) | per file |

## Reaching the service

How clients reach llama-cpp is chosen with `COMPOSE_ACCESS` in `.env`, independently of the hardware:

| `COMPOSE_ACCESS` | Effect |
|------------------|--------|
| `:docker-compose.networks.yml` | Joins `llama-net` and `nginx-proxy-net`. Other containers and the reverse proxy reach it as `llama-cpp:8080`. The default, for Hackstack servers. |
| `:docker-compose.ports.yml` | Publishes port 8080 on the host, for servers with no reverse proxy. `PUBLISHED_PORT` changes the host port and `PUBLISHED_ADDRESS` the address it binds (a LAN IP, or `127.0.0.1` for this machine only). |
| `:docker-compose.networks.yml:docker-compose.ports.yml` | Both. |
| *(empty)* | Neither; reachable only from inside the container. |

The published port maps to `LLAMA_ARG_PORT` inside the container.

`docker-compose.yml` itself has no networks and its `ports` are commented out, so nothing needs editing in any compose file.

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_STORAGE=:docker-compose.nfs.yml
```

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`.

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

From outside the container network, use the reverse-proxy hostname, or `http://<host>:8080` with `docker-compose.ports.yml`.

## API compatibility

llama.cpp server implements the OpenAI API (`/v1/chat/completions`,
`/v1/completions`, `/v1/models`, `/v1/embeddings`). Configure openwebui to
point at `http://llama-cpp:8080` as an additional OpenAI-compatible endpoint.
