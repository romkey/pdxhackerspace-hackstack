# ollama

Local LLM inference server

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

## Choosing compose files

`docker-compose.yml` is hardware-neutral and runs on the CPU by itself. Pick the
hardware override with `COMPOSE_FILE` in `.env` (the `.env.example` lists every line):

| Hardware | `COMPOSE_FILE` | Backend |
|----------|----------------|---------|
| NVIDIA discrete GPUs, DGX Spark (GB10) | `docker-compose.yml:docker-compose.nvidia.yml` | CUDA, via GPU reservation |
| NVIDIA Jetson Thor | `docker-compose.yml:docker-compose.jetson.yml` | CUDA, via the `nvidia` runtime |
| AMD Strix Halo / Strix Point | `docker-compose.yml:docker-compose.strix.yml` | ROCm (`ollama/ollama:rocm`) |
| Intel Arc | `docker-compose.yml:docker-compose.arc.yml` | Vulkan |
| CPU only | `docker-compose.yml` | CPU |

Notes:

- **NVIDIA**: needs the NVIDIA Container Toolkit. `GPU_COUNT` (`all` or a number) sets how many GPUs are reserved.
- **Jetson Thor**: the toolkit runs in CSV mode there and rejects GPU reservations, so `jetson.yml` uses `runtime: nvidia` and replaces `nvidia.yml` rather than layering on it.
- **Strix**: Strix Halo (gfx1151) and Strix Point (gfx1150) are in Ollama's ROCm support list. If `IMAGE_VERSION` is set it is the bare version (`0.40.11`); the file adds `-rocm`. For large models on Strix Halo, raise the GPU's share of system memory on the host (BIOS UMA setting and/or the `amdttm.pages_limit` kernel parameter).
- **Intel Arc**: Ollama has no oneAPI backend; Arc runs through the Vulkan backend bundled in the stock image.

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
