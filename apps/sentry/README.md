# sentry

Self-hosted error tracking and application monitoring.

This stack includes a dedicated Redis container for Sentry background jobs and caching.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

Initialize or upgrade the database schema before first start:

```bash
docker compose run --rm sentry upgrade
```

Create the first admin user:

```bash
docker compose run --rm sentry createuser
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
