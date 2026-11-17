# unifi-audit-daemon (experiment)

[unifi-audit-daemon](https://github.com/romkey/unifi-audit-daemon) keeps a complete, append-only audit log of UniFi Protect events and takes a nightly contact sheet: one still from every camera on a single JPEG. It uses Protect's private API, which can list past events, so it catches up after downtime. It serves the log and the sheets over a small HTTP API, which [Member Zone](https://github.com/pdxhackerspace/member-zone) (`apps/member-zone`) pulls into its audit logs.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

| Variable | Notes |
|----------|-------|
| `UNIFI_HOST` | The UniFi OS console running Protect |
| `UNIFI_USERNAME` / `UNIFI_PASSWORD` | A local UniFi OS account (not a UI.com cloud account) that can view Protect |
| `UNIFI_VERIFY_SSL` | Set `false` if the console still has its self-signed certificate |
| `API_TOKEN` | Bearer token Member Zone sends; at least 16 characters |
| `CONTACT_SHEET_TOKEN` | Optional read-only token for the contact sheets only |

Generate tokens with:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

See [docs/configuration.md](https://github.com/romkey/unifi-audit-daemon/blob/main/docs/configuration.md) and [docs/api.md](https://github.com/romkey/unifi-audit-daemon/blob/main/docs/api.md) for everything else.

### Data directories

The container runs as uid 10001:

```bash
mkdir -p ../../lib/unifi-audit-daemon/data ../../lib/unifi-audit-daemon/contact-sheets
sudo chown -R 10001:10001 ../../lib/unifi-audit-daemon
```

`data/` holds the audit log as JSON Lines files; it's never served and is backed up with the rest of `../../lib`. `contact-sheets/` holds the nightly sheets, kept separate so it can be shared on its own.

Member Zone reaches the API at `http://unifi-audit-daemon:8000` over `nginx-proxy-net`. Only proxy it if you want the contact sheets viewable from outside.

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
