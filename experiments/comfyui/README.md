# comfyui (experiment)

[ComfyUI](https://github.com/Comfy-Org/ComfyUI), the node-graph front end and backend for image, video and audio diffusion models, running on the [`ghcr.io/romkey/comfyui-docker`](https://github.com/romkey/comfyui-docker) image. That image comes in one variant per hardware backend; this directory has a compose file for each.

Everything persistent (models, custom nodes, inputs, outputs, user settings, kernel caches) lives in `../../lib/comfyui`, mounted at `/data`.

ComfyUI has no authentication, and ComfyUI-Manager can install arbitrary custom nodes. Don't publish port 8188; reach it only through an authenticating reverse proxy on `nginx-proxy-net`.

## Configuration

ComfyUI is configured entirely through `.env`; there is nothing to edit under `config/` unless you want extra model roots.

```bash
cp .env.example .env
mkdir -p ../../lib/comfyui
```

Then in `.env`:

1. Uncomment exactly one `COMPOSE_FILE` line for your hardware (see below). The NVIDIA CUDA 13 line is active by default.
2. Set `PUID` / `PGID` to the owner of `../../lib/comfyui`.
3. Uncomment the tuning block for your hardware, if there is one (DGX Spark, Jetson Thor, Strix Halo, Intel Arc).
4. Optionally set `HF_TOKEN` for gated Hugging Face models.

`IMAGE_VERSION` is the ComfyUI release (`latest`, `0.38.0`, or a build tag such as `0.38.0-20261007082503`). The compose files append the hardware suffix, so never put `-cpu`, `-sage`, etc. in `IMAGE_VERSION`.

The entrypoint turns `COMFYUI_*` variables into ComfyUI command-line flags. `.env.example` lists all of them; anything without a variable goes in `COMFYUI_ARGS`.

## Choosing compose files

`docker-compose.yml` is the hardware-neutral base (volumes, networks, health check). Used on its own, it runs the CPU-only image. Each hardware file layers on top of it, swapping in the matching image and passing the GPU through. Compose reads `COMPOSE_FILE` from `.env`, so plain `docker compose up -d` uses whatever you chose.

| Hardware | Image tag | `COMPOSE_FILE` |
|----------|-----------|----------------|
| NVIDIA, driver ≥ 580 (x86_64 or arm64) | `latest` | `docker-compose.yml:docker-compose.nvidia.yml` |
| NVIDIA Jetson Thor | `latest` | `docker-compose.yml:docker-compose.jetson.yml` |
| NVIDIA, driver 570–579 | `latest-cu128` | `docker-compose.yml:docker-compose.nvidia.yml:docker-compose.nvidia-cu128.yml` |
| NVIDIA Blackwell: DGX Spark (GB10), RTX 50, B200 | `latest-sage` | `docker-compose.yml:docker-compose.nvidia.yml:docker-compose.nvidia-sage.yml` |
| AMD Strix Halo / Ryzen AI Max (gfx1151), x86_64 | `latest-rocm-gfx1151` | `docker-compose.yml:docker-compose.rocm.yml` |
| Intel Arc (B580, Arc Pro B70, A-series), x86_64 | `latest-xpu` | `docker-compose.yml:docker-compose.xpu.yml` |
| No GPU, or Docker Desktop on macOS | `latest-cpu` | `docker-compose.yml` |

To pick a row:

- **NVIDIA:** run `nvidia-smi` on the host. If the driver version is 580 or newer, use the plain NVIDIA line. If it's 570–579, use `-cu128`. On a Blackwell GPU, prefer `-sage`: it turns SageAttention on automatically for compute capability 10.0, 12.0 and 12.1, and falls back to normal attention otherwise. The `-cu128` and `-sage` files only change the image, so they must come after `docker-compose.nvidia.yml`.
- **Jetson Thor:** use `docker-compose.jetson.yml` in place of `docker-compose.nvidia.yml`, not on top of it. Jetson's container toolkit runs in CSV mode, which rejects GPU device reservations (the `--gpus` equivalent that `nvidia.yml` uses) with `invoking the NVIDIA Container Runtime Hook directly ... is not supported`. The Jetson file selects the `nvidia` runtime instead. Thor is Blackwell, but SageAttention doesn't support its sm_110, so there is no `-sage` option.
- **AMD:** the ROCm image targets gfx1151 only. Other Radeon GPUs need a local build of the image against their own AMD wheel index (see the image's README).
- **Intel:** check `lspci -nnk -d 8086: | grep -A3 -E 'VGA|Display'` shows `Kernel driver in use: xe` (or `i915` for Alchemist).
- **macOS:** Docker can't pass the Apple GPU through, so this runs on CPU only. For real speed, run ComfyUI natively instead (`brew install --cask comfy`).

To keep `/data` on NFS, append `:docker-compose.nfs.yml` to whichever line you chose (see below).

Check the merged result before starting:

```bash
docker compose config --images   # should print the tag you expect
```

## Host setup per backend

**NVIDIA** needs the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/). `GPU_COUNT` limits how many GPUs are reserved (`all` by default), and `COMFYUI_CUDA_DEVICE` pins ComfyUI to one of them.

**DGX Spark and Jetson Thor** share 128 GB between CPU and GPU, so use `COMFYUI_VRAM_MODE=highvram` and set `COMFYUI_RESERVE_VRAM` to leave room for the OS and anything co-resident, such as `apps/vllm` (the example in `.env.example` reserves 30 GB for that). There's no MIG on GB10, so this fence is cooperative only. On Thor, run `sudo nvpmodel -m 0 && sudo jetson_clocks` on the host; it ships in a reduced power mode.

**Jetson Thor** needs the `nvidia` runtime registered with Docker. JetPack normally does this; check with `docker info | grep -i runtimes`. If `nvidia` is missing, run `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`.

**AMD Strix Halo** needs only the amdgpu kernel driver; the image bundles ROCm. In the BIOS, give the iGPU a small dedicated allocation and raise the kernel's GTT limit (`amdgpu.gttsize`, `ttm.pages_limit`) so it can use most of system RAM. The image already sets `HSA_ENABLE_SDMA=0`, `HSA_USE_SVM=0`, `--disable-mmap` and `--bf16-vae`.

**Intel Arc** needs the `xe` kernel driver (Linux 6.12+ for the B580, 6.17+ for the Arc Pro B70), current `linux-firmware`, and Resizable BAR plus Above 4G Decoding enabled in the BIOS. No oneAPI install is needed on the host. The first generation is slow while kernels compile; the caches persist in `/data/cache`. To confirm PyTorch sees the card:

```bash
docker exec comfyui python -c "import torch; print([torch.xpu.get_device_name(i) for i in range(torch.xpu.device_count())])"
```

With several Arc cards, ComfyUI uses only the first; set `COMFYUI_ONEAPI_DEVICE_SELECTOR=level_zero:<index>` to choose another.

## Extra model paths

To share one copy of large weights with another container, bind-mount that storage under `/data/shared-models` and set `COMFYUI_EXTRA_MODEL_PATHS_CONFIG=/config/extra_model_paths.yaml` in `.env`. `config/extra_model_paths.yaml` describes the expected layout.

## Networks

- **`nginx-proxy-net`**: reverse proxy to port **8188**
- **`llama-net`**: same LLM network as `apps/vllm`

## Storage on NFS (optional)

To keep `/data` on a NAS export instead of `../../lib/comfyui`, append `:docker-compose.nfs.yml` to `COMPOSE_FILE` and set `COMFYUI_NFS_HOST`, `COMFYUI_NFS_PATH` and `NFS_MOUNT_OPTS` (see `.env.example`).

Prefer **`hard`** NFS mounts, not `soft`. Docker creates named NFS volumes on first start; if the server or export path is wrong, fix `.env` and remove the project volume before retrying (`docker volume ls`, then `docker volume rm …`).

## Usage

Run these from this directory so Compose picks up `COMPOSE_FILE` from `.env`. Don't pass `-f docker-compose.yml`; that skips the hardware override.

```bash
docker compose up -d
docker compose logs -f
docker compose down
```

The first start takes a while; the health check allows two minutes before it counts failures. Wait for it to report `healthy` (`docker compose ps`).

`docker compose down` stops the container but leaves everything in `../../lib/comfyui`. If you switch hardware backends, run `docker compose down` before changing `COMPOSE_FILE`, then `docker compose up -d`.
