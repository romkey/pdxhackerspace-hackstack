# matrix

Self-hosted Matrix homeserver ([Synapse](https://github.com/element-hq/synapse)) with
the [Element Web](https://github.com/element-hq/element-web) browser client.

Matrix is an open, federated protocol for real-time chat.  Element Web is the
reference web client — a full-featured Slack/Teams alternative.

## Services

| Service | Image | Role |
|---|---|---|
| `synapse` | `matrixdotorg/synapse` | Matrix homeserver (API + federation) |
| `element-web` | `vectorim/element-web` | Browser-based Matrix client |

## Networks

| Network alias | Actual network | Purpose |
|---|---|---|
| `db` | `postgres-net` | Shared PostgreSQL (shared `postgresql` service) |
| `proxy` | `nginx-proxy-net` | Reverse proxy (nginx-proxy-manager) |
| `matrix` | `matrix-net` | Internal communication between Synapse and Element |

## First-time setup

### 1. Create the database

Connect to the shared PostgreSQL instance and create the Synapse database.
Synapse requires `LC_COLLATE` and `LC_CTYPE` to be `C`:

```sql
CREATE USER synapse WITH PASSWORD 'your-password';
CREATE DATABASE synapse
  ENCODING 'UTF8'
  LC_COLLATE='C'
  LC_CTYPE='C'
  TEMPLATE template0
  OWNER synapse;
```

### 2. Configure environment

```sh
cp .env.example .env
```

Edit `.env` and fill in at minimum:

- `SYNAPSE_SERVER_NAME` — the public domain for your homeserver (e.g. `matrix.example.com`)
- `POSTGRES_PASSWORD` — the password you set above
- `SYNAPSE_REGISTRATION_SHARED_SECRET` — generate with:
  ```sh
  python3 -c "import secrets; print(secrets.token_hex(32))"
  ```
- `SYNAPSE_MACAROON_SECRET_KEY` — generate with the same command

### 3. Configure Element Web

```sh
cp config/element-config.json.default config/element-config.json
```

Edit `config/element-config.json` and replace both occurrences of
`matrix.example.com` with your actual homeserver domain.

### 4. Generate the Synapse config

Synapse requires a `homeserver.yaml` to be generated before first start.
The container will do this automatically on first run if the data directory is empty,
but you can also generate it explicitly:

```sh
docker run --rm \
  -v "$(pwd)/../../lib/matrix/synapse:/data" \
  -e SYNAPSE_SERVER_NAME=matrix.example.com \
  -e SYNAPSE_REPORT_STATS=no \
  matrixdotorg/synapse:latest generate
```

Then edit `../../lib/matrix/synapse/homeserver.yaml` and update the `database:`
section to point at PostgreSQL instead of SQLite:

```yaml
database:
  name: psycopg2
  args:
    user: synapse
    password: your-password
    database: synapse
    host: postgresql
    cp_min: 5
    cp_max: 10
```

### 5. Start

```sh
docker compose up -d
```

### 6. Create the first admin user

```sh
docker exec -it synapse register_new_matrix_user \
  -c /data/homeserver.yaml \
  -u admin \
  --admin \
  http://localhost:8008
```

## Reverse proxy

Configure nginx-proxy-manager with two proxy hosts:

| Domain | Forward to | Port |
|---|---|---|
| `matrix.example.com` | `synapse` | `8008` |
| `chat.example.com` | `element-web` | `80` |

For federation to work, `matrix.example.com` must also serve
`/.well-known/matrix/server` returning `{"m.server": "matrix.example.com:443"}`.

## Stopping safely

```sh
docker compose down
```

Synapse flushes its state to PostgreSQL before exiting; no extra steps required.
