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
```

Include `REDIS_IMAGE_VERSION` when the compose file uses a separate Redis image tag.

See [Contributing](contributing.md) for compose conventions, volume layout, networks, and backup.
