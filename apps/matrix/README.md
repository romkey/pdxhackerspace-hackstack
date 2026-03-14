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

### 3. Configure Synapse

```sh
cp config/homeserver.yaml.default config/homeserver.yaml
```

Edit `config/homeserver.yaml` and replace every `CHANGEME` value:

- `server_name` — your public Matrix domain (e.g. `matrix.example.com`)
- `database.args.password` — the PostgreSQL password you set above
- `registration_shared_secret` — a long random hex string
- `macaroon_secret_key` — a second long random hex string

Generate secrets with:

```sh
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### 4. Configure Element Web

```sh
cp config/element-config.json.default config/element-config.json
```

Edit `config/element-config.json` and replace both occurrences of
`matrix.example.com` with your actual homeserver domain.

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
