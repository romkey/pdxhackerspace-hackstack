# olah (experiment)

[Olah](https://github.com/vtuber-plan/olah) is a self-hosted [Hugging Face](https://huggingface.co/) mirror. It is not a plain reverse proxy: it caches models, datasets and spaces **block by block** as clients download them, so the second machine to pull a model gets it from the LAN instead of the internet. Clients just set `HF_ENDPOINT` to point at it.

This stack runs the **[`ghcr.io/romkey/olah-docker`](https://github.com/romkey/olah-docker)** image, which installs Olah from PyPI and is rebuilt when a new release appears (pin a version with `IMAGE_VERSION`). The cache lives on an **NFS share** mounted by Docker from settings in `.env`; logs go to `../../log/olah`.

## Configuration

### 1. Environment

Copy `.env.example` to **`.env`** and set:

```bash
cp .env.example .env
```

| Variable | Notes |
|----------|-------|
| `OLAH_MIRROR_NETLOC` | Hostname clients use (no scheme), matching the `nginx-proxy-manager` proxy host. Required |
| `OLAH_MIRROR_SCHEME` | `https` behind the proxy with TLS (default), `http` otherwise |
| `OLAH_NFS_HOST` / `OLAH_NFS_PATH` | NFS server and export holding the cache. Required |
| `NFS_MOUNT_OPTS` | Options after `addr=<host>,rw`; default `nfsvers=4,hard` |
| `OLAH_CACHE_SIZE_LIMIT` | Optional ceiling such as `500GB`; empty is unlimited |
| `IMAGE_VERSION` | Image tag: `latest` (default) or an exact Olah release such as `0.5.1` |

Olah rewrites Hugging Face URLs in its responses to `OLAH_MIRROR_NETLOC`, so if it is wrong, clients will be redirected to an address they can't reach. `compose` refuses to start while `OLAH_MIRROR_NETLOC`, `OLAH_NFS_HOST` or `OLAH_NFS_PATH` is unset.

### 2. Cache over NFS

The `olah_repos` volume in `docker-compose.yml` is a Docker `local` volume with the `nfs` driver, built from `OLAH_NFS_HOST`, `OLAH_NFS_PATH` and `NFS_MOUNT_OPTS`. Nothing is stored under `../../lib/olah`.

Notes:

- The image runs Olah as uid/gid **1000**, so the export must be writable by that uid (chown it on the NAS, or map it with `all_squash`/`anonuid=1000`).
- Docker mounts the share when the volume is first created. If the NFS server is unreachable then the container won't start; fix it and run `docker volume rm olah_olah_repos` so the mount is retried. Changing the NFS settings later requires the same.
- Use **`hard`**, not `soft`: a soft mount turns a server hiccup into truncated cache blocks.
- **Cache is not portable across Olah versions.** Empty the share before changing `IMAGE_VERSION`.
- **Backups:** the cache is re-downloadable, so it is not backed up by `backrest`.

### 3. Log directory

```bash
mkdir -p ../../log/olah
sudo chown 1000:1000 ../../log/olah
```

### 4. Policy (`config/configs.toml`)

Host, port, mirror URL, cache path and size limit come from the command line (from `.env`) and override `configs.toml`. Edit **`config/configs.toml`** for the cache-clean strategy (`LRU`, `FIFO`, `LARGE_FIRST`), `offline` mode, and per-repo allow/deny rules for proxying and caching.

### 5. Reverse proxy

Point `nginx-proxy-manager` at **`olah:8090`** for the `OLAH_MIRROR_NETLOC` hostname. Model files are huge: disable request/response buffering and raise (or disable) the proxy timeouts and `client_max_body_size`.

## Using the mirror

On any client:

```bash
export HF_ENDPOINT=https://olah.pdxhackerspace.org
hf download openai-community/gpt2
```

The first download fills the cache from huggingface.co; later ones are served from NFS. Gated repositories still need the client's own `HF_TOKEN`.

## Networks

- **`nginx-proxy-net`** — reverse proxy to container port **8090**

## Healthcheck

The image's built-in healthcheck (`nc -z localhost 8090`).

## Usage

### Start

```bash
docker compose up -d
```

### Stop

```bash
docker compose down
```

### Logs

```bash
docker compose logs -f
```
