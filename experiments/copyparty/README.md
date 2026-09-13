# copyparty (experiment)

[copyparty](https://github.com/9001/copyparty) is a portable file server: browser upload/download with resumable, deduplicated uploads, media thumbnails and an audio player, file search, and access via WebDAV, FTP and SMB as well as HTTP.

## Prerequisites

**`nginx-proxy-net`** (from `apps/nginx-proxy-manager`) must exist.

Create the data directories on the host, owned by the user the container runs as (`PUID`/`PGID` in `.env`, default `1000:1000`):

```bash
mkdir -p ../../lib/copyparty/cfg ../../lib/copyparty/files
sudo chown -R 1000:1000 ../../lib/copyparty
```

## Configuration

```bash
cp .env.example .env
cp config/copyparty.conf.default config/copyparty.conf
```

Both copies are gitignored.

**`config/copyparty.conf`** defines accounts, volumes and permissions. The default has a single **`admin`** account with password **`changeme`** and no anonymous access — **change the password before starting**. Accounts are listed under **`[accounts]`**, and each volume's **`accs:`** block grants permissions (`r` read, `w` write, `m` move, `d` delete, `a` admin, `g` get-only, `h` get + folder index). `*` means everyone, including anonymous users.

To share more directories, add a bind mount in `docker-compose.yml` (for example `/srv/media:/w/media:ro`) and a matching volume section in the config:

```ini
[/media]
  /w/media
  accs:
    r: *
```

Restart after editing the config: `docker compose restart`.

## Reverse proxy

Point nginx-proxy-manager at **`copyparty:3923`** (or publish **`3923`** temporarily — see the commented **`ports`** in `docker-compose.yml`).

The config trusts **`X-Forwarded-For`** from private networks (`xff-src: lan`) so logs and rate limiting see the real client IP. Uploads are sent in chunks, so the proxy does not need an unlimited body size, but enable **Websockets Support** and consider adding `proxy_request_buffering off;` in the host's advanced config for faster uploads.

WebDAV works through the proxy at the same URL. FTP and SMB are off by default and are not proxied; they need extra config options and published ports.

## Networks

- **`nginx-proxy-net`** — browser access via proxy

## Usage

From the repo root:

```bash
bin/install-experimental.sh        # copy .env and config, set TZ
bin/install-experimental.sh start  # after the proxy is up
```

Or manually:

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

## Healthcheck

`docker-compose.yml` requests `/` from inside the container every 30s with the image's Python; any HTTP response (including 401/403 when anonymous access is off) counts as healthy.

## Backup

- **`../../lib/copyparty/files`** — the shared files
- **`../../lib/copyparty/cfg`** — sessions, the file index and thumbnails (the index and thumbnails are rebuilt if lost)
- **`config/copyparty.conf`** — accounts and permissions (gitignored, so back it up separately)
