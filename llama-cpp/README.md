# llama-cpp

OpenAI-compatible local LLM inference server based on
[llama.cpp](https://github.com/ggml-org/llama.cpp). Runs GGUF-format models
on CPU or GPU and exposes them as an OpenAI API endpoint on `llama-net`,
making it usable by [openwebui](../openwebui/) and
[home-assistant](../home-assistant/) alongside [ollama](../ollama/).

## Hardware backend

The Docker image tag selects the hardware backend. Set `IMAGE_VERSION` in
`.env` to choose:

| `IMAGE_VERSION` | Backend |
|-----------------|---------|
| `server` _(default)_ | CPU only |
| `server-cuda` | NVIDIA GPU (requires nvidia container runtime) |
| `server-rocm` | AMD GPU (requires ROCm) |
| `server-vulkan` | Vulkan — Intel/AMD integrated graphics |

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
| `LLAMA_ARG_N_GPU_LAYERS` | Layers to offload to GPU (`0` = CPU only, `-1` = all) | `0` |
| `LLAMA_ARG_CTX_SIZE` | Context window size in tokens | `4096` |
| `LLAMA_ARG_THREADS` | CPU threads to use | `4` |
| `LLAMA_ARG_HOST` | Bind address inside the container | `0.0.0.0` |
| `LLAMA_ARG_PORT` | Port inside the container | `8080` |
| `IMAGE_VERSION` | Image tag / hardware backend (see table above) | `server` |

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
