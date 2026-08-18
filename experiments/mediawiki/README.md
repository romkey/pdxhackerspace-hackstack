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

Two scripts in **`bin/`**, meant to be run in this order:

| Script | What it does |
|---|---|
| **`migrate-wikijs-users.sh`** | Creates a MediaWiki account for each Wiki.js user, with their email address and groups |
| **`migrate-wikijs.sh`** | Converts pages to wikitext and imports them, optionally crediting each one to its author |

Requirements: `postgresql` and `mediawiki` containers running, MediaWiki already installed (`LocalSettings.php` in place), bash 4 or newer, and — for page conversion — either `pandoc` on the host or the ability to pull the **`pandoc/core`** image. Both scripts keep their state in **`../../run/mediawiki/wikijs-migration`**.

### Where the database settings come from

Neither script has a configuration file of its own, and neither reads this directory's **`.env`**. Both work out the two databases at run time, in different ways.

**Wiki.js** is read directly over SQL, so it needs credentials. They come from **`apps/wiki/.env`** if that file exists, and otherwise from the **`db:`** block of **`apps/wiki/config.yml`**, which is where a normal Wiki.js install keeps them:

| `apps/wiki/.env` | `apps/wiki/config.yml` | Default |
|---|---|---|
| `DB_TYPE` | `type` | `postgres` |
| `DB_HOST` | `host` | `postgresql` |
| `DB_PORT` | `port` | `5432` |
| `DB_USER` | `user` | — |
| `DB_PASS` | `pass` | — |
| `DB_NAME` | `db` | — |

Only `postgres` is supported; any other type stops the run. `psql` is executed **inside the `postgresql` container**, so the host name is resolved from that container's networks — which is why the `postgresql` default works, and why the `wiki` container itself need not be running. Every run reports which file it used and what it connected to, without the password:

```
Wiki.js credentials: /srv/hackstack/apps/wiki/config.yml
Database:            wikijs@postgresql:5432/wikijs
```

**MediaWiki** needs no credentials at all. Nothing is written over SQL: pages and accounts go in through MediaWiki's own maintenance scripts run inside the `mediawiki` container, and those read **`LocalSettings.php`** for the database name, user and password the web installer generated. So the wiki being written to is whichever one `LocalSettings.php` points at, and its bind mount has to be uncommented in **`docker-compose.yml`** (see [First-time web install](#first-time-web-install)) — without it the scripts stop rather than guess.

Paths and file names are derived from the repo layout. Override them with environment variables if your tree differs:

| Variable | Default | Used for |
|---|---|---|
| `WIKI_DIR` | `../../apps/wiki` | Where to look for Wiki.js credentials |
| `PG_COMPOSE` | `../../apps/postgresql/docker-compose.yml` | Compose file holding the `postgresql` service |
| `MW_COMPOSE` | `./docker-compose.yml` | Compose file holding the `mediawiki` service |
| `PANDOC_IMAGE` | `pandoc/core:latest` | Converter image, when `pandoc` is not on the host |
| `MARKDOWN_FORMAT` | `gfm` | The pandoc reader used for Wiki.js markdown |

The services in those compose files must be named `postgresql` and `mediawiki`.

### Accounts

Accounts have to exist **before** anyone signs in through SSO. MediaWiki otherwise creates a brand new empty account the first time each person logs in, and there is then nothing sensible to attribute imported pages to.

```bash
./bin/migrate-wikijs-users.sh --dry-run   # report the mapping and stop
./bin/migrate-wikijs-users.sh             # create the accounts
```

Each account is created with a random password which is then scrambled, so it can only be used through SSO. Give someone a local password afterwards with `changePassword.php` if you need to.

| Option | Effect |
|---|---|
| `--dry-run` | Report the planned accounts and stop |
| `--username-from name\|email` | Derive user names from the Wiki.js display name (default) or from the local part of the email address |
| `--on-collision source\|number\|skip` | How to separate colliding names (default `source`) |
| `--group-map MAP` | Wiki.js to MediaWiki group mapping (default `Administrators=sysop+bureaucrat`) |
| `--active-only` | Skip users Wiki.js has marked inactive |

Details worth knowing:

- **Users who share an email address become one account.** The email address is what an SSO login is matched on, so two Wiki.js identities with the same address cannot become two accounts. Their groups are combined and both Wiki.js user ids are recorded, so pages from either identity are credited to the surviving account.
- **Colliding names get the identity source appended**, giving `John Romkey (local)` and `John Romkey (slack)`. The source is the name of the Wiki.js authentication strategy, lowercased — `local`, `slack`, `authentik`. Two same-named users from the *same* source fall back to a number, as in `Same Name (slack) 2`.
- **Names MediaWiki cannot accept are reported and skipped** rather than mangled. So are Wiki.js groups with no mapping, which grant nothing.
- Users with no email address are still created, so their pages can be credited, but no SSO login can ever claim them.
- The run writes **`users.tsv`**, one row per Wiki.js user id, which the page migration reads for attribution. It is only written for real runs, never dry runs.

Re-running is safe: existing accounts have their groups and email address brought up to date rather than being duplicated.

### SSO

MediaWiki does SSO through [PluggableAuth](https://www.mediawiki.org/wiki/Extension:PluggableAuth) and [OpenID Connect](https://www.mediawiki.org/wiki/Extension:OpenID_Connect), which accept **several issuers at once** — Slack and Authentik can both be offered while Slack is being retired:

```php
wfLoadExtension( 'PluggableAuth' );
wfLoadExtension( 'OpenIDConnect' );

// Let a login adopt the account migrated for that email address instead of
// creating a duplicate. Off by default, and only applies to accounts that have
// never been used with SSO.
$wgOpenIDConnect_MigrateUsersByEmail = true;

$wgPluggableAuth_Config['Log in with Authentik'] = [
    'plugin' => 'OpenIDConnect',
    'data' => [
        'providerURL'  => 'https://authentik.example.org/application/o/mediawiki/',
        'clientID'     => '...',
        'clientsecret' => '...',
    ],
];
$wgPluggableAuth_Config['Log in with Slack'] = [
    'plugin' => 'OpenIDConnect',
    'data' => [
        'providerURL'  => 'https://slack.com',
        'clientID'     => '...',
        'clientsecret' => '...',
    ],
];
```

The email address the provider asserts must match the one migrated from Wiki.js, or the person gets a second account.

### Pages

**`migrate-wikijs.sh`** copies pages out of the Wiki.js PostgreSQL database, converts them from Markdown or HTML to wikitext with pandoc, and writes them in through MediaWiki's own maintenance scripts so link tables and the search index stay consistent.

```bash
./bin/migrate-wikijs.sh --dry-run              # report the title mapping and stop
./bin/migrate-wikijs.sh --attribute --assets   # migrate, crediting authors, with uploads
```

| Option | Effect |
|---|---|
| `--dry-run` | Print the title mapping and stop |
| `--attribute` | Credit each page to the account of its Wiki.js author, from `users.tsv` |
| `--attribute-by author\|creator` | Credit the last editor (default) or the original creator |
| `--titles` | Title pages from the Wiki.js title instead of the page path |
| `--prefix TEXT` | Prepend a prefix or namespace to every title, e.g. `Wiki:` |
| `--include-unpublished` | Also migrate Wiki.js drafts |
| `--locale CODE` | Migrate a locale other than `en` |
| `--assets` | Export Wiki.js uploads and import them as files |
| `--export-only` / `--import-only` | Split the run so converted wikitext can be reviewed first |
| `--user NAME` | Account to use for pages with no migrated author |
| `--no-bot` | Leave the imported edits out of the bot flag, so they show in Recent changes |

By default `guides/laser-cutter` becomes **`Guides/Laser cutter`**, and links between migrated pages are retargeted at the new titles. Converted files are left in the work directory so a run can be reviewed or repeated; re-running is safe, since importing identical text is a no-op.

`--attribute` needs `users.tsv` from the account migration and refuses to run without it. This is deliberate: `edit.php` silently creates any account named with `-u`, so attributing to names that were never migrated would invent accounts.

Known limits:

- Pages that are neither `markdown` nor `html` in Wiki.js (for example `asciidoc`) are reported and skipped.
- Titles come from the page path, so `safety/ppe` becomes `Safety/Ppe`, not `Safety/PPE`. Use `--titles` to take Wiki.js page titles instead.
- Section anchors keep their Wiki.js spelling, so a link to `#ppe` may need to become `#PPE` to match MediaWiki's heading anchors.
- Page history and comments are not migrated: each page arrives as a single revision, credited to its last author.
- **Uploads only come across with `--assets`**, which is off by default; without it, images in imported pages are red links. The run says so at the end.
- `--assets` needs uploads enabled (`$wgEnableUploads`) and flattens Wiki.js folders, since MediaWiki file names are global. Colliding names are reported and skipped.
- MediaWiki only accepts extensions listed in **`$wgFileExtensions`**, which by default covers common images and nothing else — no PDFs, and none of the CAD or cutter formats a shop wiki tends to collect. `importImages` ignores the rest without comment, so the script reports how many were left out. Add the extensions you want to `LocalSettings.php` and re-run with `--import-only --assets`.

### Retiring Slack as an identity source

Once someone has signed in through Slack, their account is bound to Slack's issuer in the **`openid_connect`** table, and `$wgOpenIDConnect_MigrateUsersByEmail` will not rebind it. To hand those accounts to Authentik, drop the Slack bindings and remove the Slack issuer from `$wgPluggableAuth_Config`:

```sql
DELETE FROM openid_connect WHERE oidc_issuer = 'https://slack.com';
```

Each account then has no issuer again, so the next Authentik login adopts it by email address, keeping the user's name, groups and page history. Take a database backup first, and check the table for a `$wgDBprefix` if you set one.

## Backup

- MariaDB: include your wiki database in normal DB backups; **`mkdb.sh`** can add **`BACKUP_DATABASE_URLS`** to `.env`.
- Files: back up **`../../lib/mediawiki`** (`images/` and **`LocalSettings.php`** after install).
