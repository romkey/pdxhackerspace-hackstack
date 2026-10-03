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

**`config/copyparty.conf`** defines accounts, groups, volumes and permissions. Before starting:

1. Change the **`admin`** password (default **`changeme`**) and set the **`lan`** account's password to a long random string.
2. Create the folders: `mkdir -p ../../lib/copyparty/files/public ../../lib/copyparty/files/internal`

Accounts are listed under **`[accounts]`**, members under **`[groups]`**, and each volume's **`accs:`** block grants permissions (`r` read, `w` write, `m` move, `d` delete, `a` admin/create shares, `g` download only with the URL, `h` like `g` plus folder index.html). `*` means everyone, including anonymous users.

### Access model

| Folder (URL) | Hackerspace LAN | Internet | Upload / manage |
|---|---|---|---|
| `/` (`files/`) | browse without login | login, filekey link, or share link | members |
| `/public` (`files/public`) | browse without login | browse without login | members |
| `/internal` (`files/internal`) | browse without login | login only; no share links | members |

Access is set per folder, not per file: to make a file internal-only or public, move it into that folder.

- **LAN without login.** `ipu` logs LAN clients in as the read-only `lan` user, and `ipr` refuses that account from anywhere else. This depends on copyparty seeing the real client IP, so keep `xff-src: lan` and `rproxy: -1`. **Never set `rproxy: 1`**: it trusts the client-supplied first `X-Forwarded-For` entry, which anyone on the Internet can forge to claim a LAN address.
- **Filekey links.** In `/`, anonymous Internet users have `g` (get) with `fk: 8`. They can't list folders or guess filenames; members copy a file's link (which includes `?k=…`) from the UI.
- **Share links.** Members create them with the share button; they appear under `/share/`, optionally with a password and expiry. Set `site:` to the public URL so the links use it. `/internal` disables shares.

`ipu`/`ipr` are set to **`192.168.0.0/16`**, the hackerspace network including all VLANs.

Docker networks on the hackstack host are allocated outside that range (`default-address-pools` in `/etc/docker/daemon.json`), so containers are never mistaken for LAN clients. Keep it that way: a Docker network inside `192.168.0.0/16` would be treated as LAN.

Internet traffic reaches nginx-proxy-manager directly through the router, so it arrives with real public addresses. If that ever changes — a tunnel or proxy on the LAN in front of NPM (Cloudflare Tunnel, Tailscale Funnel) — Internet visitors would look like LAN clients; exclude that address from `ipu` or pass the real IP through and adjust `rproxy`/`xff-hdr`. LAN clients that use the public hostname are hairpinned by the router and show up with its LAN address, which is still treated as internal.

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

The config trusts **`X-Forwarded-For`** from private networks (`xff-src: lan`) and uses the address the proxy appended (`rproxy: -1`), so LAN detection, logs and rate limiting see the real client IP. Uploads are sent in chunks, so the proxy does not need an unlimited body size, but enable **Websockets Support** and consider adding `proxy_request_buffering off;` in the host's advanced config for faster uploads.

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
