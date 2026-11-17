# grafana (experiment)

[Grafana](https://grafana.com/) metrics visualization and dashboards. It uses the shared PostgreSQL (`postgresql` on `postgres-net`) for its own data and joins `prometheus-net` to query **`experiments/prometheus`** (data source URL `http://prometheus:9090`).

## Configuration

### Database

Create the database with the shared cluster helper:

```bash
../../apps/postgresql/bin/mkdb.sh grafana
```

That creates `grafana_db` owned by `grafana_user` and prints a password. Put it in `.env` as `GF_DATABASE_PASSWORD`.

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

| Variable | Notes |
|----------|-------|
| `GF_SERVER_ROOT_URL` | Public URL served by nginx-proxy-manager |
| `GF_SECURITY_ADMIN_PASSWORD` | Initial admin password (only used when the admin user is first created) |
| `GF_DATABASE_PASSWORD` | Password from `mkdb.sh` |

Any `grafana.ini` setting can be set as `GF_<SECTION>_<KEY>`. 

### Login with authentik (optional)

1. In authentik, create an **OAuth2/OpenID Provider** with redirect URI `https://<your grafana host>/login/generic_oauth` and an **Application** with slug `grafana`.
2. Optionally create groups `Grafana Admins` and `Grafana Editors`; other users get the Viewer role.
3. Uncomment the `GF_AUTH_GENERIC_OAUTH_*` block in `.env`, fill in the client ID and secret, and replace `auth.example.com` with your authentik host.
4. `GF_SERVER_ROOT_URL` must be the public URL, or the redirect URI Grafana sends won't match.

Once OIDC login works you can set `GF_AUTH_DISABLE_LOGIN_FORM=true` to hide the password form.

### Configuration Files

Copy `config/grafana.ini.example` to `config/grafana.ini`. The `config/` directory is mounted at `/etc/grafana`; put datasource and dashboard provisioning files in `config/provisioning/`.

### Data directories

Grafana runs as uid 472:

```bash
mkdir -p ../../lib/grafana ../../log/grafana
sudo chown 472:0 ../../lib/grafana ../../log/grafana
```

Point nginx-proxy-manager at `grafana:3000`.

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
