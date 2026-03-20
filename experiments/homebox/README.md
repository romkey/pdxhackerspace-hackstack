# homebox (experiment)

[HomeBox](https://github.com/sysadminsmedia/homebox) is a self-hosted home inventory and organization app (SQLite, low resource use). This stack runs the maintained **`ghcr.io/sysadminsmedia/homebox`** image (continuation of the original hay-kot project).

## Configuration

### Environment

Copy `.env.example` to `.env`:

```bash
cp .env.example .env
```

Set `IMAGE_VERSION` if you want to pin a tag other than `latest` (see [GHCR packages](https://github.com/sysadminsmedia/homebox/pkgs/container/homebox)).

Additional runtime tuning can use `HBOX_*` variables; see the [HomeBox documentation](https://homebox.software/).

### Config file (required)

The image expects **`/data/config.yml`** on the persistent volume (same directory as the SQLite database).

1. Ensure the data directory exists (repository convention):

   ```bash
   mkdir -p ../../lib/homebox
   ```

2. Install the config once:

   ```bash
   cp config/config.yml.default ../../lib/homebox/config.yml
   ```

3. Edit `../../lib/homebox/config.yml` as needed (public URL / hostname, OIDC, mailer, registration policy, etc.).

For **`latest-rootless`** or **`latest-hardened`**, the upstream image may require ownership on `/data` (e.g. `chown 65532:65532`); see the [HomeBox quick start](https://homebox.software/en/quick-start/).

## Networks

- **`nginx-proxy-net`** — attach your reverse proxy vhost to the container’s internal port **7745**.

## Usage

### Start

```bash
docker compose up -d
```

### Stop

```bash
docker compose down
```

### Logs

```bash
docker compose logs -f
```

### Backup

Back up the directory **`../../lib/homebox`** (includes `config.yml`, SQLite DB, and uploads).
