# headscale (experiment)

[Headscale](https://headscale.net/) is a self-hosted implementation of the Tailscale control server. Tailscale clients (the stock ones, on any platform) register against it instead of Tailscale's SaaS, and it hands out `100.64.0.0/10` addresses, distributes keys, runs MagicDNS and enforces ACLs. Traffic between nodes stays peer-to-peer WireGuard and never passes through this container; only coordination does.

It is here as an experiment because it changes how people reach the space's network from outside, which is worth trying before it becomes part of the core stack.

Headscale is only the control server. Members' laptops and phones run the ordinary Tailscale client pointed at it, and **`experiments/tailscale`** is the `tailscaled` node for the server itself — the piece that puts Hackstack on the tailnet and can advertise the space's LAN to remote members.

**[Headplane](https://headplane.net/)** is the optional web UI in the same compose stack: manage users, nodes, pre-auth keys, ACLs, and DNS settings without living on the CLI.

## Prerequisites

**`nginx-proxy-net`** (from `apps/nginx-proxy-manager`) must exist.

Create the data and socket directories on the host:

```bash
mkdir -p ../../lib/headscale ../../lib/headplane ../../run/headscale
```

You also need two DNS names, and they must be different from each other:

- one for headscale itself, which becomes **`server_url`** (for example `headscale.example.org`)
- one for MagicDNS, which becomes **`base_domain`** (for example `ts.example.org`). Headscale takes this domain over inside the tailnet, so pointing it at the same name as `server_url` makes headscale unreachable from its own clients.

## Configuration

```bash
cp .env.example .env
cp config/config.yaml.default config/config.yaml
cp config/headplane.yaml.default config/headplane.yaml
```

Nearly everything lives in **`config/config.yaml`** and **`config/headplane.yaml`**; `.env` holds image tags, Headplane secrets, and optionally OIDC client secrets. At a minimum, set **`server_url`** and **`dns.base_domain`** in `config.yaml`, and **`server.base_url`** in `headplane.yaml` to the same public hostname (without `/admin`).

Generate a 32-character cookie secret for Headplane and put it in `.env`:

```bash
pwgen 32 1   # copy into HEADPLANE_SERVER__COOKIE_SECRET
```

`config.yaml` and `headplane.yaml` are gitignored, since they can hold secrets. Check your edits before starting:

```bash
docker compose run --rm headscale configtest
```

### Reverse proxy

Point nginx-proxy-manager at **`headscale:8080`**, with TLS on the public side and **Websockets Support turned on** in the proxy host's Details tab. Websockets are not optional: the Tailscale Control Protocol upgrades to one, using `POST` for the upgrade request and `tailscale-control-protocol` as the `Upgrade` header value, and a proxy that does not pass those through leaves clients unable to register. The control connection is also long-lived, so raise the proxy read timeout if clients reconnect on a fixed interval.

Serve Headplane under the **same hostname** at **`/admin`**. In nginx-proxy-manager, add a **Custom Location** on that proxy host:

| Setting | Value |
| --- | --- |
| Location | `/admin` |
| Forward Hostname / IP | `headplane` |
| Forward Port | `3000` |
| Websockets Support | on |

The UI lives at **`https://headscale.example.org/admin`**. `server.base_url` in `headplane.yaml` must be `https://headscale.example.org` — the hostname only, no path.

Headscale serves plain HTTP here and logs `listening without TLS but ServerURL does not start with http://` at startup, which is expected when the proxy terminates TLS. Its own Let's Encrypt support goes unused for the same reason.

Two things cannot go through the proxy: STUN for the embedded DERP server (UDP 3478, direct), and gRPC for remote CLI access.

### Headplane

Headplane talks to headscale over **`http://headscale:8080`** on `nginx-proxy-net`. Docker integration is on so DNS and settings edits in the UI can restart headscale; that needs the **`me.tale.headplane.target`** label on the headscale service (already in `docker-compose.yml`) and read-only access to **`/var/run/docker.sock`**.

After the stack is up, create an API key and put it in **`HEADPLANE_HEADSCALE__API_KEY`** in `.env`:

```bash
docker compose exec headscale headscale apikeys create --expiration 90d
docker compose up -d headplane   # reload env if headplane was already running
```

Log in at **`/admin`** with that key until OIDC is configured. Headplane stores its own data under **`../../lib/headplane`**.

## OIDC / Authentik

Out of the box, OIDC is off and nodes join with pre-auth keys. The **`oidc`** block at the bottom of `config/config.yaml.default` is a commented-out skeleton; filling in `issuer`, `client_id` and `client_secret` is all it takes to turn SSO on.

In Authentik:

1. Create an **OAuth2/OpenID provider**. Authorization flow: whichever one you use for other applications; signing key: the default. Client type is **Confidential**.
2. Set the redirect URI to **`https://headscale.example.org/oidc/callback`** (exact match).
3. Create an **Application** bound to that provider and note its slug.
4. Bind whatever policy or group decides who may reach the application.

Then in `config/config.yaml`, uncomment the `oidc` block and set:

```yaml
oidc:
  issuer: "https://authentik.example.org/application/o/<application-slug>/"
  client_id: "<client id from Authentik>"
  client_secret: "<client secret from Authentik>"
  pkce:
    enabled: true
```

The trailing slash on `issuer` matters — headscale appends `.well-known/openid-configuration` to it for discovery. Authentik supports PKCE, so leave it enabled.

To keep the secret out of `config/`, leave `client_secret` commented out and put **`HEADSCALE_OIDC_CLIENT_SECRET`** in `.env` instead (see `.env.example` for the caveat about environment variables).

Restricting who gets in is done with `allowed_domains`, `allowed_users` and `allowed_groups`. Group names are matched against the `groups` claim, which Authentik only sends if the provider's scope mapping includes it — add the built-in `authentik default OAuth Mapping: OpenID 'profile'` scope or a custom mapping that emits `groups`, otherwise `allowed_groups` matches nothing and every login is rejected.

Note that `only_start_if_oidc_is_available` defaults to **true**: if Authentik is down when headscale starts, headscale refuses to start.

Nodes already registered with pre-auth keys keep working after OIDC is turned on; the two registration methods coexist.

### Headplane SSO (optional)

Headplane has its own **`oidc`** block in `config/headplane.yaml` (commented out in the default). It is independent of headscale's `oidc` block — two different redirect URIs — but Authentik can use **one OAuth2 provider** with both:

| Consumer | Redirect URI |
| --- | --- |
| Headscale (node login) | `https://headscale.example.org/oidc/callback` |
| Headplane (admin UI) | `https://headscale.example.org/admin/oidc/callback` |

Use the same **`client_id`** in both configs when possible. Uncomment the `oidc` section in `headplane.yaml`, set `issuer` and `client_id`, and put the client secret in **`HEADPLANE_OIDC__CLIENT_SECRET`** in `.env`. Headplane still needs **`HEADPLANE_HEADSCALE__API_KEY`** for server-side API calls even when SSO is on.

## First run

```bash
docker compose up -d
```

Then create a user and a key for it. `--user` wants the numeric id that `users list` prints, not the name:

```bash
docker compose exec headscale headscale users create alice
docker compose exec headscale headscale users list
docker compose exec headscale headscale preauthkeys create --user 1 --expiration 24h
```

On the client, which needs to be Tailscale **1.80 or newer** — 0.29.3 rejects anything older:

```bash
tailscale up --login-server https://headscale.example.org --authkey <key>
```

With OIDC configured, skip the pre-auth key — `tailscale up --login-server https://headscale.example.org` prints a URL that sends the user through Authentik, and the headscale user is created from the token.

The CLI works from the host too, through the unix socket in `../../run/headscale`, but running it with `docker compose exec` is simpler.

To put the Hackstack server itself on the tailnet, or to advertise the space's LAN to remote members, bring up **`experiments/tailscale`** with a key from the same command. Routes it advertises need approving here:

```bash
docker compose exec headscale headscale nodes list-routes
docker compose exec headscale headscale nodes approve-routes --identifier 1 --routes 192.168.1.0/24
```

Testing this on a Mac rather than the server: headscale exits with `chmod /var/run/headscale/headscale.sock: invalid argument` because Docker Desktop's shared filesystem will not chmod a socket. Swap the `../../run/headscale` bind mount for a `tmpfs` while you are on a laptop; on Linux the bind mount is fine.

## Networks

- **`nginx-proxy-net`** — client and browser access via the proxy
- optional, commented out — **`postgres-net`**, only if you switch the database to the shared PostgreSQL

## Database

SQLite under **`../../lib/headscale`** is the default and is what upstream develops and tests against. PostgreSQL is supported but explicitly discouraged, and is kept only for legacy installations — the commented `postgres` block in `config.yaml.default` is there if you want it anyway.

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

## Healthcheck

The headscale image is distroless, so there is no shell or `wget` to probe with. `docker-compose.yml` runs **`headscale health`**, which talks to the server over the unix socket and exits non-zero if it does not answer.

Headplane ships **`/bin/hp_healthcheck`**, which the compose file runs every 30s.

## Backup

Back up **`../../lib/headscale`**: it holds `db.sqlite` and its WAL files, the Noise private key, and the DERP key if the embedded relay is ever enabled. Losing the Noise key forces every node to re-register.

Copying a live SQLite file can capture an inconsistent database, so add a dump to `.env` as well and let `apps/db-backup` handle it:

```bash
BACKUP_DATABASE_URLS=sqlite:////opt/lib/headscale/db.sqlite
```

Also keep copies of **`config/config.yaml`** and **`config/headplane.yaml`** somewhere outside the repo, since both are gitignored.

Back up **`../../lib/headplane`** as well if you use Headplane — it holds Headplane's database and caches.

## Upgrading

Headscale migrates its schema on startup and does not support downgrades. Keep **`IMAGE_VERSION`** pinned to a full version rather than `latest` or `stable` — that also keeps Watchtower from moving the service across releases on its own — and back up `../../lib/headscale` before bumping it. Read the [upgrade guide](https://headscale.net/stable/setup/upgrade/) before moving between minor versions.
