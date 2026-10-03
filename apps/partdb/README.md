# partdb

Electronic parts inventory management

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

## Usage

### Starting the service

```bash
docker compose up -d
```

### Database migrations

Part-DB does not apply schema updates automatically when the container image
changes. Run migrations after first install and after every version upgrade.

**First install** — after configuring `.env` and starting the container:

```bash
docker compose up -d
docker exec --user=www-data partdb php bin/console doctrine:migrations:migrate
```

On a fresh database this creates the schema and prints the initial admin
password. Follow the prompts.

**Upgrading** — after pulling a new image:

```bash
docker compose pull
docker compose up -d
docker exec --user=www-data partdb php bin/console doctrine:migrations:migrate
```

Back up the database before upgrading. Major-version upgrades may require
additional steps — see the
[Part-DB upgrade documentation](https://docs.part-db.de/upgrade/).

### SSO (Authentik SAML)

Part-DB supports login SSO via **SAML 2.0 only** (not OIDC). All settings
are environment variables — see the commented block in `.env.example`.

#### 1. Generate a service-provider key pair

Part-DB needs an SP certificate and private key. Generate one with OpenSSL:

```bash
openssl req -new -x509 -days 3650 -nodes -out sp.crt -keyout sp.key
```

Copy the base64 body of each file (between the `BEGIN`/`END` lines, with no
whitespace or line breaks) into `SAML_SP_X509_CERT` and `SAML_SP_PRIVATE_KEY`
in `.env`.

#### 2. Create an Authentik SAML provider

In Authentik, create a **SAML** provider and application for Part-DB. Use
**POST** bindings. Set the service provider URLs to match your public hostname:

| Setting | Value |
|---|---|
| ACS URL | `https://partdb.example.com/saml/acs` |
| Logout URL | `https://partdb.example.com/logout` |
| Audience / SP entity ID | `https://partdb.example.com/sp` |

Import or paste the SP certificate from step 1. Copy the provider metadata
values into `.env`:

- `SAML_IDP_ENTITY_ID` — Entity ID / Issuer from the Authentik provider
- `SAML_IDP_SINGLE_SIGN_ON_SERVICE` — SSO URL (**Post** binding)
- `SAML_IDP_SINGLE_LOGOUT_SERVICE` — SLO URL (**Post** binding)
- `SAML_IDP_X509_CERT` — IdP signing certificate (base64 body)

Also set:

```bash
DEFAULT_URI=https://partdb.example.com/
SAML_ENABLED=1
SAML_BEHIND_PROXY=1
SAML_SP_ENTITY_ID=https://partdb.example.com/sp
TRUSTED_PROXIES=172.16.0.0/12
```

Adjust `TRUSTED_PROXIES` for your Docker network. Map Authentik groups to
Part-DB groups with `SAML_ROLE_MAPPING` (group IDs are on **System →
Groups** in Part-DB). See the
[Part-DB SAML documentation](https://docs.part-db.de/installation/saml_sso.html)
for attribute and role-mapping details.

Restart after editing `.env`:

```bash
docker compose up -d
```

Local and SAML users are separate accounts. To move an existing local user to
SAML login:

```bash
docker exec --user=www-data partdb php bin/console partdb:user:convert-to-saml-user USERNAME
```

Keep at least one local admin account for access if Authentik is unavailable.

### Stopping the service

```bash
docker compose down
```

### Viewing logs

```bash
docker compose logs -f
```
