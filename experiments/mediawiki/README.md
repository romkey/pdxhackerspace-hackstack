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

From the repo root:

```bash
bin/install-experimental.sh        # copy .env, set TZ
bin/install-experimental.sh start  # after mkdb.sh and proxy/mariadb are up
```

Or manually:

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

## Healthcheck

HTTP **`GET /`** on **`127.0.0.1:80`** via PHP inside the container (the official image does not ship `curl` at runtime).

## Migrating from Wiki.js

**`bin/migrate-wikijs.sh`** copies pages out of the **`apps/wiki`** (Wiki.js) PostgreSQL database, converts them from Markdown or HTML to wikitext with pandoc, and writes them into MediaWiki through its maintenance scripts so link tables and the search index stay consistent.

Wiki.js database credentials are read from **`apps/wiki/.env`** if it exists, otherwise from the **`db:`** block of **`apps/wiki/config.yml`**.

Requirements: `postgresql`, `wiki` and `mediawiki` containers running, MediaWiki already installed (`LocalSettings.php` in place), and either `pandoc` on the host or the ability to pull the **`pandoc/core`** image.

Preview the page-title mapping without writing anything:

```bash
./bin/migrate-wikijs.sh --dry-run
```

Then migrate, optionally bringing Wiki.js uploads over as MediaWiki files:

```bash
./bin/migrate-wikijs.sh --assets
```

Useful options (`--help` lists them all):

| Option | Effect |
|---|---|
| `--dry-run` | Print the title mapping and stop |
| `--titles` | Title pages from the Wiki.js title instead of the page path |
| `--prefix TEXT` | Prepend a prefix or namespace to every title, e.g. `Wiki:` |
| `--include-unpublished` | Also migrate Wiki.js drafts |
| `--locale CODE` | Migrate a locale other than `en` |
| `--assets` | Export Wiki.js uploads and import them as files |
| `--export-only` / `--import-only` | Split the run so converted wikitext can be reviewed first |
| `--user NAME` | Attribute edits to an existing MediaWiki account |

By default `guides/laser-cutter` becomes **`Guides/Laser cutter`**, and links between migrated pages are retargeted at the new titles. Converted files are left in **`../../run/mediawiki/wikijs-migration`** so a run can be reviewed or repeated; re-running is safe, since importing identical text is a no-op.

Known limits:

- Pages that are neither `markdown` nor `html` in Wiki.js (for example `asciidoc`) are reported and skipped.
- Section anchors keep their Wiki.js spelling, so a link to `#ppe` may need to become `#PPE` to match MediaWiki's heading anchors.
- Page history, comments, users and permissions are not migrated; each page arrives as a single revision.
- `--assets` needs uploads enabled (`$wgEnableUploads`) and flattens Wiki.js folders, since MediaWiki file names are global. Colliding names are reported and skipped.

## Backup

- MariaDB: include your wiki database in normal DB backups; **`mkdb.sh`** can add **`BACKUP_DATABASE_URLS`** to `.env`.
- Files: back up **`../../lib/mediawiki`** (`images/` and **`LocalSettings.php`** after install).
