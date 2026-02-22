# auto_planka

Automation scripts for [Planka](https://planka.app/), the kanban board.
Performs periodic tasks against the Planka PostgreSQL database directly.

Image source: [romkey/pdxhackstack-auto-planka](https://github.com/romkey/pdxhackstack-auto-planka)

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `POSTGRESQL` | Full PostgreSQL connection URL for the Planka database |
| `IMAGE_VERSION` | Docker image tag (optional, defaults to `latest`) |

### Configuration Files

Task/automation configuration lives in `config/`. See the source repo for
details on the config format.

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
