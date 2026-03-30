# mediawiki (experiment)

[MediaWiki](https://www.mediawiki.org/) using the official **[`mediawiki`](https://hub.docker.com/_/mediawiki)** Apache image and the **shared MariaDB** service (`mariadb` on `mariadb-net`).

The image includes **MySQL/MariaDB** support (`mysqli`) only, not PostgreSQL—use **`apps/mariadb`**, not `apps/postgresql`, for the database.

## Prerequisites

1. **`nginx-proxy-net`** (e.g. from `nginx-proxy-manager`) and **`mariadb-net`** (from `apps/mariadb`) must exist; MariaDB must be running.

2. Create an application database and user (names and password are up to you; `mediawiki` is a common prefix):

   ```bash
   ../../apps/mariadb/bin/mkdb.sh mediawiki
   ```

   That creates **`mediawiki_db`**, **`mediawiki_user`**, and a generated password (and may append **`BACKUP_DATABASE_URLS`** to this directory’s `.env` if present).

3. Create the images volume directory on the host:

   ```bash
   mkdir -p ../../lib/mediawiki/images
   ```

## Configuration

```bash
cp .env.example .env
```

Set **`IMAGE_VERSION`** if you pin a tag. Optionally set **`TZ`**.

## First-time web install

1. Point your reverse proxy at **`mediawiki:80`** (or publish **`80`** temporarily—see commented **`ports`** in **`docker-compose.yml`**).

2. Open the wiki URL in a browser. On **“Set up database”** use:

   - Database type: **MySQL/MariaDB**
   - Database host: **`mariadb`**
   - Database name: **`mediawiki_db`** (or whatever you used with **`mkdb.sh`**)
   - Database user / password: **`mediawiki_user`** / password from **`mkdb.sh`**

3. When the installer offers **`LocalSettings.php`**, save it as **`../../lib/mediawiki/LocalSettings.php`** on the host.

4. Uncomment the **`LocalSettings.php`** bind mount in **`docker-compose.yml`** and **`docker compose up -d`** again so upgrades and restarts keep your settings.

## Networks

- **`nginx-proxy-net`** — browser access via proxy
- **`mariadb-net`** — SQL to **`mariadb:3306`**

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

## Healthcheck

HTTP **`GET /`** on **`127.0.0.1:80`** inside the container.

## Backup

- MariaDB: include your wiki database in normal DB backups; **`mkdb.sh`** can add **`BACKUP_DATABASE_URLS`** to `.env`.
- Files: back up **`../../lib/mediawiki`** (`images/` and **`LocalSettings.php`** after install).
