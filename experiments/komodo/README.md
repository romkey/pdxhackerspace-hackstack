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

  The two secrets are any long random strings; generate each with:

  ```bash
  openssl rand -hex 32
  ```

  - `KOMODO_WEBHOOK_SECRET` verifies webhooks from GitHub, Forgejo and other git providers. Enter the same value as the secret when you add the webhook on the provider.
  - `KOMODO_JWT_SECRET` signs login sessions. Keep it stable: changing it logs everyone out.
- `PERIPHERY_CONNECT_AS` must match `KOMODO_FIRST_SERVER_NAME`.
- `PERIPHERY_ROOT_DIRECTORY` is where Komodo keeps the stacks, repos and builds it manages. It's mounted at the same path inside the container, so it must be an absolute host path.

Point nginx-proxy-manager at `komodo-core:9120`.

Periphery has the Docker socket mounted and can control every container on the host.

### Single sign-on (authentik)

Create an OAuth2/OpenID provider and application in authentik with the slug `komodo`, and set its redirect URI to:

```
https://komodo.example.com/auth/oidc/callback
```

That's `KOMODO_HOST` followed by `/auth/oidc/callback`, so it must match `KOMODO_HOST` in `.env` exactly (scheme and host included). Then set in `.env`:

| Variable | Value |
|----------|-------|
| `KOMODO_OIDC_ENABLED` | `true` |
| `KOMODO_OIDC_PROVIDER` | `https://<authentik host>/application/o/komodo` (no trailing slash). Komodo Core must be able to reach this URL. |
| `KOMODO_OIDC_CLIENT_ID` | the provider's client ID |
| `KOMODO_OIDC_CLIENT_SECRET` | the provider's client secret |

GitHub or Google login use `KOMODO_HOST/auth/github/callback` and `KOMODO_HOST/auth/google/callback` instead. See [Komodo's advanced setup docs](https://komo.do/docs/setup/advanced).

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
