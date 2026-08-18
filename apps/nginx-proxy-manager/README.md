# nginx-proxy-manager

Reverse proxy and TLS termination for Hackstack services. We run this with SQLite3 to avoid a MySQL dependency.

## Configuration

Copy `.env.example` to `.env` if you need to override the image version:

```bash
cp .env.example .env
```

Persistent data lives under `../../lib/nginx-proxy-manager`. Configure proxy hosts in the web UI after first login.

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

## Troubleshooting

[Forgot your password?](https://github.com/NginxProxyManager/nginx-proxy-manager/discussions/1634)

Follow those instructions to the letter. Do *not* delete the account and create a new one from SQL; this will break relations between existing proxy hosts and users.
