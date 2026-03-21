# authentik

Identity Provider and SSO solution

## Configuration

### Redis (`authentik-redis`)

Redis runs with **no AOF** and **no RDB** (`save ""`) to limit SSD wear. Cache and sessions are **volatile** across unclean restarts—users may need to **sign in again**. See [redis-persistence-hackstack.md](../../docs/redis-persistence-hackstack.md).

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

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
