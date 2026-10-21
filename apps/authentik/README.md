# authentik

Identity provider and SSO (OAuth/SAML/LDAP and more).

## Configuration

Copy `.env.example` to `.env` and set secrets, database, and email settings. Create the PostgreSQL database with `apps/postgresql/bin/mkdb.sh` (or set `AUTHENTIK_POSTGRESQL__*` manually).

### Redis (`authentik-redis`)

If you enable the bundled Redis service, it runs with **no AOF** and **no RDB** (`save ""`) to limit SSD wear. Cache and sessions are **volatile** across unclean restarts—users may need to **sign in again**. See [redis-persistence-hackstack.md](../../docs/redis-persistence-hackstack.md).

### Optional LDAP outpost

LDAP is **not** part of the default stack. To expose Authentik as an LDAP directory (e.g. for Linux hosts via SSSD), use **`docker-compose.ldap.yml`**.

1. In Admin: create an **LDAP provider** and application, then **Applications → Outposts → Create** with type **LDAP**, integration **`----`** (manual), and assign the LDAP application.
2. Copy the generated **outpost token** into `.env` as `AUTHENTIK_LDAP_OUTPOST_TOKEN`.
3. Set `AUTHENTIK_LDAP_OUTPOST_HOST` to the URL the outpost uses to reach the Authentik API (usually your public HTTPS URL, or `http://authentik-server:9000` with `AUTHENTIK_LDAP_OUTPOST_INSECURE=true` on `nginx-proxy-net`).
4. Enable the overlay in `.env`:

   ```bash
   COMPOSE_FILE=docker-compose.yml:docker-compose.ldap.yml
   ```

5. `docker compose up -d`. LDAP listens on host ports **389** / **636** (override with `LDAP_PORT` / `LDAPS_PORT`).

Host LDAP clients can target **`authentik-ldap`** on the Docker host (add `/etc/hosts` or LAN DNS as needed). For Debian/SSSD setup see [`bin/debian-ldap-login.sh`](../../bin/debian-ldap-login.sh).

Official docs: [LDAP provider](https://docs.goauthentik.io/add-secure-apps/providers/ldap/), [manual outpost compose](https://docs.goauthentik.io/add-secure-apps/outposts/manual-deploy-docker-compose/).

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
