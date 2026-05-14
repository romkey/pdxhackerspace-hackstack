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
| `IMAGE_VERSION` | Docker tag for `vllm/vllm-openai` (default in compose: `latest`). Pick a version that matches your CUDA stack. |
| `GPU_COUNT` | Number of NVIDIA GPUs to assign (default `1` in compose). Set in `.env` to match the host. |
| `HF_TOKEN` | Optional. For gated or private Hugging Face models, set the token in `.env` (vLLM reads the standard `HF_TOKEN` / `HUGGING_FACE_HUB_TOKEN` env vars). |

### AMD / ROCm

The compose file uses `vllm/vllm-openai` (NVIDIA). For AMD GPUs, change the `image` in `docker-compose.yml` to `vllm/vllm-openai-rocm` (and a suitable tag) and follow the vLLM Docker notes for ROCm. Remove or adjust the `deploy.resources` GPU block if your runtime does not use NVIDIA device reservation.

### CPU-only

vLLM is aimed at GPU inference. Running CPU-only is not the typical path; for CPU inference in this stack, consider [llama-cpp](../llama-cpp/) or [ollama](../ollama/).

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
