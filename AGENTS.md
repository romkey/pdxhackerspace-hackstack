# Working on Hackstack

Rules for AI agents (and humans) adding or changing apps in this repository. Read this before touching anything under `apps/`, `experiments/` or `deprecated/`.

Hackstack is the set of Docker Compose apps PDX Hackerspace runs on its servers. It's installed at `/opt/docker`, so each app lives at `/opt/docker/<namespace>/<app>` and its data at `/opt/lib/<app>`, `/opt/log/<app>` and `/opt/run/<app>`. Background and rationale: [docs/contributing.md](docs/contributing.md), [docs/design.md](docs/design.md), [docs/macvlan.md](docs/macvlan.md).

## The core rule: nobody edits a compose file to deploy an app

Whoever runs an app configures it **only** through `.env` and files under `config/`. They must never have to edit `docker-compose.yml` or any other compose file, and should be able to `git pull` new versions without merge conflicts.

So every choice a deployment needs to make lives in `.env`:

- **Values** (hostnames, ports, credentials, tuning) are environment variables read through `env_file: .env` or `${VAR:-default}` interpolation.
- **Structural choices** (GPU vs CPU, NFS, macvlan, publishing ports, joining the proxy network) are separate overlay compose files, switched on with `COMPOSE_FILE` in `.env`.

If you find yourself writing "uncomment this line in docker-compose.yml" in a README, make it an overlay or a variable instead. The only exception left in the repo is commented-out `ports:` kept as documentation.

## Layout

```
apps/<app>/          # in production use
experiments/<app>/   # being tried out; same conventions, nothing special about installing them
deprecated/<app>/    # retired; kept for reference, not maintained
  docker-compose.yml
  docker-compose.<overlay>.yml   # optional overlays (see below)
  .env.example                   # committed; every variable, secrets as placeholders
  .env                           # real values; never committed
  config/                        # config files the app reads; *.example committed, real files ignored
  README.md
  .gitignore                     # app-relative paths, e.g. `.env`, `config/app.yml`
  .rsync.exclude                 # optional; live database files to leave out of file backups
```

- The directory name is the app name. Use it for the main service's `container_name` and `hostname`, and for its data directories.
- Moving an app between namespaces is a plain `git mv`; also remove it from `bin/install-*.sh` and fix any docs that point at the old path.
- **Never edit the top-level `.gitignore` or `.rsync.exclude`.** GitHub Actions regenerates them from the per-app files.

## docker-compose.yml

```yaml
services:
  myapp:
    image: vendor/myapp:${IMAGE_VERSION:-latest}
    container_name: myapp
    hostname: myapp
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./config:/config:ro
      - ../../lib/myapp:/data
      - ../../log/myapp:/var/log/myapp
#    ports:
#      - 8080:8080
    networks:
      - proxy
      - db
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://127.0.0.1:8080/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

networks:
  proxy:
    external: true
    name: nginx-proxy-net
  db:
    external: true
    name: postgres-net
```

- **No `version:` key.**
- **Image tags** come from a variable with a default: `${IMAGE_VERSION:-latest}`. Extra images get their own variable (`REDIS_IMAGE_VERSION`, `MONGO_IMAGE_VERSION`). Pin a major version instead of `latest` when upstream breaks things across majors or doesn't publish `latest`.
- **Every service** has `container_name`, `hostname`, `restart: unless-stopped` and, where at all possible, a `healthcheck` that uses a tool the image actually contains (check for `curl`/`wget`/`python` before using it).
- **No constants in compose files.** Environment comes from `env_file: .env`. An `environment:` block is only acceptable for mapping one `.env` variable onto another name (`MONGO_INITDB_ROOT_PASSWORD: ${KOMODO_DATABASE_PASSWORD}`) or for a default the image needs.
- **Locally built or pinned images** that Watchtower shouldn't update get the label `com.centurylinklabs.watchtower.enable=false`.

### Storage

- **Bind mounts with relative paths only.** No absolute host paths, no named Docker volumes (except NFS volumes in `docker-compose.nfs.yml`).
  - `./config` - configuration the user edits
  - `../../lib/<app>` - persistent state; backed up automatically
  - `../../log/<app>` - logs; not backed up
  - `../../run/<app>` - caches, sockets, pid files; not backed up
- Multi-service apps use subdirectories: `../../lib/<app>/redis`, `../../lib/<app>/storage`.
- If the image runs as a fixed non-root uid, the README says which and gives the `mkdir`/`chown` commands.
- Rare exception: a path that must be identical inside and outside the container (Komodo's periphery root, for example) is an absolute path from `.env` with a sensible default.

### Networking

- **Don't publish ports.** Web UIs are reached through nginx-proxy-manager on `nginx-proxy-net` by container name. Leave the `ports:` block commented out as documentation of the port the app listens on.
- Publish ports only when the protocol can't go through the proxy (MQTT, DNS, NUT, SSH for git). Mark it with `# hackstack: ports required`.
- Join only the networks an app needs. Shared networks are all `external: true`:

  | Alias | Network | For |
  |-------|---------|-----|
  | `proxy` | `nginx-proxy-net` | reachable through the reverse proxy |
  | `db` | `postgres-net` | shared PostgreSQL (host `postgresql`) |
  | `mariadb` | `mariadb-net` | shared MariaDB (host `mariadb`) |
  | `mqtt` | `mosquitto-net` | MQTT broker (host `mosquitto`) |
  | `mail` | `postfix-net` | outbound mail relay (host `postfix`) |
  | `hass` | `hass-net` | Home Assistant integrations |
  | `llama` | `llama-net` | local LLM servers and their clients |
  | `prometheus` | `prometheus-net` | Prometheus and its exporters |
  | `mdns` | `mdns-net` | mDNS relayed from the LAN |

  A private network for an app's own sidecars (Redis, its own database) is named `<app>-net` or `<app>-redis-net` and isn't external.
- **Host networking (`network_mode: host`) only when nothing else works**, for example a device that replies to a fixed UDP port on the host. Comment why next to it (`# hackstack: host networking required - ...`), and explain the consequences in the README (it reaches other services through their published host ports, and its own ports bind on the host).
- **When an app needs to look like a device on the LAN** (mDNS, broadcasts, AirPlay, Matter, DHCP/PXE, a stable LAN IP), use macvlan rather than host mode: keep bridge networking in `docker-compose.yml` and add a `docker-compose.macvlan.yml` overlay that attaches the external `lan_macvlan` network with `IPV4_ADDRESS` and `LAN_MAC_ADDRESS` from `.env`. See [docs/macvlan.md](docs/macvlan.md) and `apps/esphome` for the pattern.

### Databases and Redis

- **Use the shared PostgreSQL or MariaDB.** Never bundle a Postgres or MariaDB/MySQL service. Create the database with `../../apps/postgresql/bin/mkdb.sh <app>` (or the MariaDB equivalent), which creates `<app>_db` / `<app>_user`, prints the password and appends `BACKUP_DATABASE_URLS` to `.env`.
- Prefer PostgreSQL when the app supports both. When an app can only use SQLite, that's fine; document `BACKUP_DATABASE_URLS=sqlite:////opt/lib/<app>/...` for the real `.env`.
- **Redis is per app**: its own service, on its own private network, data in `../../lib/<app>/redis`.
- An app that needs a database the shared services can't provide (MongoDB for Komodo, for example) bundles it on a private network, and the README says why.

## Overlays and COMPOSE_FILE

Anything a deployment might want one way or the other is an overlay file next to `docker-compose.yml`, enabled from `.env`. Compose reads `COMPOSE_FILE` from `.env`, so a plain `docker compose up -d` picks it up. Tell users never to pass `-f docker-compose.yml`, which skips the overlays.

| Overlay | Purpose |
|---------|---------|
| `docker-compose.nfs.yml` | Large data on an NFS export instead of `../../lib` (named volume with `driver_opts.type: nfs`, `*_NFS_HOST`/`*_NFS_PATH`/`NFS_MOUNT_OPTS` from `.env`, prefer `hard`) |
| `docker-compose.macvlan.yml` | Attach to `lan_macvlan` with a static LAN IP and MAC |
| `docker-compose.<hardware>.yml` | GPU backends (`nvidia`, `jetson`, `strix`, `arc`, ...) on a hardware-neutral base |
| `docker-compose.networks.yml` | Join the Hackstack networks (proxy, LLM, ...) |
| `docker-compose.ports.yml` | Publish the port on the host for servers with no reverse proxy (`PUBLISHED_ADDRESS`, `PUBLISHED_PORT`) |

For a single overlay, `.env.example` has a commented line such as `# COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml`.

When an app has several independent choices, `.env.example` assembles `COMPOSE_FILE` from one variable per choice, so the user picks each one separately (see `apps/vllm`, `apps/llama-cpp`, `experiments/comfyui`):

```bash
COMPOSE_HARDWARE=:docker-compose.nvidia.yml
COMPOSE_ACCESS=:docker-compose.networks.yml
COMPOSE_STORAGE=
COMPOSE_FILE=docker-compose.yml${COMPOSE_STORAGE}${COMPOSE_HARDWARE}${COMPOSE_ACCESS}
```

Put overlays that use `!override` before ones that add to the same key. After adding overlays, check each combination with `docker compose config -q`.

## .env and .env.example

- **Secrets are never committed.** Not in `.env.example`, not in compose files, not in `config/*.example`, not in READMEs or commit messages. `.env` and real config files are git-ignored per app.
- Every variable the compose file or app uses appears in `.env.example`, grouped under comment headers, with a one-line explanation where it isn't obvious.
- Secrets get a placeholder: `<FILL IN>`, `<DATABASE PASSWORD>`, or empty, plus how to generate one (`openssl rand -hex 32`).
- Optional features are commented out with their default value shown.
- Include `IMAGE_VERSION` (and any other image tag variables) and `TZ=America/Los_Angeles` when the app uses a timezone.
- Use container names for hosts on shared networks: `postgresql`, `mariadb`, `mosquitto`, `postfix`, `<app>-redis`.
- **Never define `BACKUP_DATABASE_URLS` in `.env.example`**; `mkdb.sh` appends it. Keep the standard comment about it at the end of the file.
- Anything upstream's README documents should be configurable here, with a link to upstream's full reference.

## config/

- Configuration files the app reads go in `config/` next to the compose file, never another directory name. Mount them read-only where the app allows.
- Commit an example (`config/<file>.example`, or `.default` where the app already uses that) and git-ignore the real file in the app's `.gitignore`.
- Prefer environment variables in `.env` over config files when the app supports both. Keep config examples short and commented; don't paste upstream's whole default file unless it's needed.
- Credentials an app needs as files go under a git-ignored subdirectory such as `config/secrets/`.

## README.md

Start from [docs/app-readme-template.md](docs/app-readme-template.md). Every README has:

- A title of the app name, with ` (experiment)` for experiments, and a sentence or two on what it does, linking upstream.
- For multi-service apps, a table of the services.
- **Configuration**: `cp .env.example .env`, a table of the variables that must be set, database creation (`mkdb.sh`), config files to copy, data directories to create and `chown`, and the proxy target (`<app>:<port>`).
- A section for each overlay the app ships and how to enable it in `.env`.
- Anything unusual and why (host networking, a bundled database, the Docker socket, published ports, no authentication).
- **Usage**: `docker compose up -d`, `docker compose down`, `docker compose logs -f`.

Write plainly. Don't tell the user to edit compose files.

## Backups

- `../../lib/<app>` is backed up file by file. Live database files there can't be copied safely while the app runs, so list them in the app's `.rsync.exclude` (paths relative to `/opt`, e.g. `lib/myapp/app.db`) and back them up with `BACKUP_DATABASE_URLS` or the app's own dump feature instead.
- Logs (`../../log`) and caches (`../../run`) aren't backed up.

## Checking your work

- `docker compose config -q` with `.env.example` copied to `.env` (delete the copy afterwards), for every overlay combination you touched.
- `.github/scripts/validate_compose.py` encodes the compose rules and runs in CI.
- `grep` the repo for the app's name and old paths when you add, move or rename one: `bin/install-*.sh`, `docs/`, other apps' READMEs and `experiments/prometheus/config/prometheus.yml.example`.
