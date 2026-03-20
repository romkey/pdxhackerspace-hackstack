# homebox (experiment)

[HomeBox](https://github.com/sysadminsmedia/homebox) is a self-hosted home inventory and organization app. This stack runs the maintained **`ghcr.io/sysadminsmedia/homebox`** image and uses the **shared PostgreSQL** service (`postgresql` on `postgres-net`) for the database; uploads and `config.yml` stay on **`../../lib/homebox`** (mounted at `/data`).

## Configuration

### 1. PostgreSQL database

Create a dedicated database and user with the shared cluster helper (from **`apps/postgresql`**):

```bash
../../apps/postgresql/bin/mkdb.sh homebox
```

That creates **`homebox_db`** owned by **`homebox_user`** and prints a password. Put that password in **`.env`** as **`HBOX_DATABASE_PASSWORD`** (see `.env.example`).

### 2. Environment

Copy `.env.example` to **`.env`** and set **`HBOX_DATABASE_PASSWORD`** (and **`IMAGE_VERSION`** if you pin a tag).

```bash
cp .env.example .env
```

### 3. Config file (required)

The image expects **`/data/config.yml`** on the persistent volume.

```bash
mkdir -p ../../lib/homebox
cp config/config.yml.default ../../lib/homebox/config.yml
```

Edit **`../../lib/homebox/config.yml`** if you change DB name, user, host, or TLS. By default it targets **`postgresql:5432`** with **`ssl_mode: disable`** on the internal Docker network.

For **`latest-rootless`** or **`latest-hardened`**, see the [HomeBox quick start](https://homebox.software/en/quick-start/) for `/data` ownership (e.g. `chown 65532:65532`).

## Networks

- **`postgres-net`** — database (`postgresql` hostname)
- **`nginx-proxy-net`** — reverse proxy to container port **7745**

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

- **PostgreSQL:** include `homebox_db` in your normal DB backups (e.g. `BACKUP_DATABASE_URLS` pattern used elsewhere in this repo).
- **Files:** back up **`../../lib/homebox`** (`config.yml`, uploads under the storage prefix on `/data`).
