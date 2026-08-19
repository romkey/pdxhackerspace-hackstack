# headscale (experiment)

[Headscale](https://headscale.net/) is a self-hosted implementation of the Tailscale control server. Tailscale clients (the stock ones, on any platform) register against it instead of Tailscale's SaaS, and it hands out `100.64.0.0/10` addresses, distributes keys, runs MagicDNS and enforces ACLs. Traffic between nodes stays peer-to-peer WireGuard and never passes through this container; only coordination does.

It is here as an experiment because it changes how people reach the space's network from outside, which is worth trying before it becomes part of the core stack.

Headscale is only the control server. Members' laptops and phones run the ordinary Tailscale client pointed at it, and **`experiments/tailscale`** is the `tailscaled` node for the server itself — the piece that puts Hackstack on the tailnet and can advertise the space's LAN to remote members.

## Prerequisites

**`nginx-proxy-net`** (from `apps/nginx-proxy-manager`) must exist.

Create the data and socket directories on the host:

```bash
mkdir -p ../../lib/headscale ../../run/headscale
```

You also need two DNS names, and they must be different from each other:

- one for headscale itself, which becomes **`server_url`** (for example `headscale.example.org`)
- one for MagicDNS, which becomes **`base_domain`** (for example `ts.example.org`). Headscale takes this domain over inside the tailnet, so pointing it at the same name as `server_url` makes headscale unreachable from its own clients.

## Configuration

```bash
cp .env.example .env
cp config/config.yaml.default config/config.yaml
```

Nearly everything lives in **`config/config.yaml`**; `.env` only holds the image tag, the timezone, and optionally the OIDC client secret. At a minimum, set **`server_url`** and **`dns.base_domain`** in `config.yaml`.

`config.yaml` is gitignored, since it can hold the OIDC client secret. Check your edits before starting:

```bash
docker compose run --rm headscale configtest
```

### Reverse proxy

Point nginx-proxy-manager at **`headscale:8080`**, with TLS on the public side and **Websockets Support turned on** in the proxy host's Details tab. Websockets are not optional: the Tailscale Control Protocol upgrades to one, using `POST` for the upgrade request and `tailscale-control-protocol` as the `Upgrade` header value, and a proxy that does not pass those through leaves clients unable to register. The control connection is also long-lived, so raise the proxy read timeout if clients reconnect on a fixed interval.

Headscale serves plain HTTP here and logs `listening without TLS but ServerURL does not start with http://` at startup, which is expected when the proxy terminates TLS. Its own Let's Encrypt support goes unused for the same reason.

Two things cannot go through the proxy: STUN for the embedded DERP server (UDP 3478, direct), and gRPC for remote CLI access.

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

The image is distroless, so there is no shell or `wget` to probe with. `docker-compose.yml` runs **`headscale health`**, which talks to the server over the unix socket and exits non-zero if it does not answer.

## Backup

Back up **`../../lib/headscale`**: it holds `db.sqlite` and its WAL files, the Noise private key, and the DERP key if the embedded relay is ever enabled. Losing the Noise key forces every node to re-register.

Copying a live SQLite file can capture an inconsistent database, so add a dump to `.env` as well and let `apps/db-backup` handle it:

```bash
BACKUP_DATABASE_URLS=sqlite:////opt/lib/headscale/db.sqlite
```

Also keep a copy of **`config/config.yaml`** somewhere outside the repo, since it is gitignored.

## Upgrading

Headscale migrates its schema on startup and does not support downgrades. Keep **`IMAGE_VERSION`** pinned to a full version rather than `latest` or `stable` — that also keeps Watchtower from moving the service across releases on its own — and back up `../../lib/headscale` before bumping it. Read the [upgrade guide](https://headscale.net/stable/setup/upgrade/) before moving between minor versions.
