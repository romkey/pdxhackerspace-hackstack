# Application README template

Use this template for new Hackstack applications. Copy it to `apps/<name>/README.md` or `experiments/<name>/README.md`.

For **experiments**, include `(experiment)` in the title.

For **multi-service stacks** (Rails + Sidekiq + Redis, Celery workers, etc.), add sections for Services, Network dependencies, and First-time setup — see `apps/glitchtip/README.md` or `apps/member-zone/README.md`.

---

```markdown
# app-name

One or two sentences describing what this service does and who uses it.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

Document any required variables in a table or bullet list. Point to files under `config/` when configuration lives there instead of `.env`.

### Storage on NFS (optional)

If the app ships `docker-compose.nfs.yml`, document how to set `COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml` and the `*_NFS_*` variables in `.env.example`.

### LAN macvlan (optional)

If the app ships `docker-compose.macvlan.yml`, document `COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml`, `IPV4_ADDRESS`, `LAN_MAC_ADDRESS`, and shared `MACVLAN_*` variables (see [macvlan.md](macvlan.md)).

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
```

## `.env.example` template

Every application with environment variables in `docker-compose.yml` or `env_file:` needs a `.env.example`:

```bash
IMAGE_VERSION=latest
TZ=America/Los_Angeles

# App-specific variables (redact secrets)
SECRET_KEY=

# BACKUP_DATABASE_URLS — apps/postgresql/bin/mkdb.sh or apps/mariadb/bin/mkdb.sh appends this to .env when you
# create the app database (unless .env already defines it). For SQLite or other URLs, set it only in your
# real .env. Do not define BACKUP_DATABASE_URLS in .env.example.

# --- Optional: large data on NFS (when docker-compose.nfs.yml exists) ---
# COMPOSE_FILE=docker-compose.yml:docker-compose.nfs.yml
# MYAPP_NFS_HOST=
# MYAPP_NFS_PATH=
# NFS_MOUNT_OPTS=nfsvers=4,hard
```

Include `REDIS_IMAGE_VERSION` when the compose file uses a separate Redis image tag.

See [Contributing](contributing.md) for compose conventions, volume layout, networks, and backup.
