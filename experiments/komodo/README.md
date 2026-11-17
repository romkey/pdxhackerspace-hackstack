# komodo (experiment)

[Komodo](https://komo.do) is a web UI for building and deploying software and managing Docker containers and compose stacks across one or more servers.

This stack runs Komodo Core (the web UI/API), Komodo Periphery (the agent that talks to the local Docker daemon), and its own MongoDB, which Komodo requires.

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

- `MONGO_INITDB_ROOT_PASSWORD` and `KOMODO_DATABASE_PASSWORD` must match.
- Set `KOMODO_INIT_ADMIN_PASSWORD`, `KOMODO_WEBHOOK_SECRET` and `KOMODO_JWT_SECRET`.
- `PERIPHERY_CONNECT_AS` must match `KOMODO_FIRST_SERVER_NAME`.
- `PERIPHERY_ROOT_DIRECTORY` is where Komodo keeps the stacks, repos and builds it manages. It's mounted at the same path inside the container, so it must be an absolute host path.

Point nginx-proxy-manager at `komodo-core:9120`.

Periphery has the Docker socket mounted and can control every container on the host.

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
