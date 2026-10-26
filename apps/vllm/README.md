# vllm

OpenAI-compatible LLM serving using [vLLM](https://docs.vllm.ai/) (`vllm serve`). Models are loaded from [Hugging Face](https://huggingface.co/) (or local paths you mount) with weights cached under `../../lib/vllm/huggingface` on the host, mapped to `/root/.cache/huggingface` in the container.

The service is attached to `llama-net` (and `nginx-proxy-net`) on port **8000** inside the container, similar to [llama-cpp](../llama-cpp/) and [ollama](../ollama/) for use with [openwebui](../openwebui/) and other clients.

## Configuration

Copy the example environment file and edit it:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `VLLM_MODEL` | **Required.** Model id (e.g. `meta-llama/Llama-3.2-3B-Instruct`) or a path to weights inside the container. |
| `VLLM_ARGS` | **Optional.** Extra arguments for `vllm serve`, space-separated (e.g. `--max-model-len 8192 --tensor-parallel-size 2`). Same flags as the [vLLM engine / CLI](https://docs.vllm.ai/) documentation. |
| `IMAGE_VERSION` | vLLM release tag (e.g. `v0.32.0`, default `latest`). The CUDA, CPU, ROCm and XPU images share version tags, so it applies to whichever file you use. |
| `GPU_COUNT` | Number of NVIDIA GPUs to reserve with `nvidia.yml` (default `1`). |
| `HF_TOKEN` | Optional. For gated or private Hugging Face models, set the token in `.env` (vLLM reads the standard `HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` env vars). |

## Choosing compose files

`docker-compose.yml` is hardware-neutral and runs the CPU image by itself. Pick
the hardware override with `COMPOSE_FILE` in `.env` (the `.env.example` lists every line):

| Hardware | `COMPOSE_FILE` | Image |
|----------|----------------|-------|
| NVIDIA discrete GPUs, DGX Spark (GB10) | `docker-compose.yml:docker-compose.nvidia.yml` | `vllm/vllm-openai` (CUDA 13) |
| DGX Spark, community GB10 build | `docker-compose.yml:docker-compose.nvidia.yml:docker-compose.spark.yml` | `ghcr.io/spark-arena/dgx-vllm-eugr-nightly` |
| NVIDIA Jetson Thor | `docker-compose.yml:docker-compose.jetson.yml` | `vllm/vllm-openai`, `nvidia` runtime |
| AMD Strix Halo / Strix Point | `docker-compose.yml:docker-compose.strix.yml` | `vllm/vllm-openai-rocm` |
| Intel Arc | `docker-compose.yml:docker-compose.arc.yml` | `vllm/vllm-openai-xpu` |
| CPU only | `docker-compose.yml` | `vllm/vllm-openai-cpu` |

`.env.example` has tuned, commented-out settings for each platform, including a `VLLM_ARGS` line per platform; uncomment the block for your hardware (only one `VLLM_ARGS` line).

Notes:

- **NVIDIA**: needs the NVIDIA Container Toolkit and driver >= 580 for the CUDA 13 images. With a 575-579 driver, pin a CUDA 12.9 build, e.g. `IMAGE_VERSION=v0.32.0-cu129`.
- **DGX Spark**: the stock image runs on GB10. `spark.yml` swaps in a community build with Spark-specific kernels; its tag is `SPARK_IMAGE_VERSION`, not `IMAGE_VERSION`.
- **Spark and Thor** share CPU and GPU memory, so lower `--gpu-memory-utilization` in `VLLM_ARGS` to leave room for the OS and other services.
- **Jetson Thor**: the stock arm64 CUDA 13 image includes sm_110 kernels. The toolkit runs in CSV mode there and rejects GPU reservations, so `jetson.yml` uses `runtime: nvidia` and replaces `nvidia.yml` rather than layering on it.
- **Strix**: vLLM supports Ryzen AI Max (gfx1151) and Ryzen AI 300 (gfx1150) on ROCm >= 7.0.2, which the official ROCm image bundles. Expect fewer optimized kernels than on Instinct or Radeon cards.
- **Intel Arc**: Battlemage (B580, Arc Pro B-series) is what Intel tests; Alchemist may work but is slow. Needs Intel compute runtime >= 26.18 on the host. Upstream's example runs the container privileged; uncomment `privileged: true` in `arc.yml` if no XPU device is found. With NFS, put `docker-compose.nfs.yml` before `arc.yml` so the `/dev/dri/by-path` mount survives.
- **CPU**: works on x86_64 (AVX-512 recommended, AVX2 limited) and arm64, but is slow; it is mainly useful for testing. Size the KV cache with `VLLM_CPU_KVCACHE_SPACE` (GB). For real CPU inference in this stack, use [llama-cpp](../llama-cpp/) or [ollama](../ollama/).

## Starting and stopping

```bash
docker compose up -d
docker compose down
```

Logs: `docker compose logs -f`

## Health and API

The healthcheck calls `http://127.0.0.1:8000/v1/models`. Expose port 8000 or use a reverse proxy on `nginx-proxy-net` to reach the service. Example:

```bash
curl -sS http://vllm:8000/v1/models
```

(From another container on `llama-net` or the proxy network.)

## Notes

- `ipc: host` matches the vLLM Docker documentation for better performance; it is not the same as `network_mode: host`.
- First start can take a long time while weights download and load; the health check allows a 5-minute start period.

## Storage on NFS (optional)

Large data defaults to bind mounts under `../../lib/` in `docker-compose.yml`. To use a NAS export instead, set in **`.env`** (see **`.env.example`**):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.nvidia.yml:docker-compose.nfs.yml
```

(use your hardware line, with `docker-compose.nfs.yml` last, except on Intel Arc)

plus the `*_NFS_HOST`, `*_NFS_PATH`, and `NFS_MOUNT_OPTS` variables documented in `.env.example`. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` picks up the override.

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).
