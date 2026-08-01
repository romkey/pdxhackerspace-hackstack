#!/bin/bash
#
# migrate-wikijs.sh
# Migrate pages (and optionally assets) from Wiki.js to MediaWiki.
#
# Wiki.js keeps page source in PostgreSQL, so pages are read straight out of
# the database rather than through its API. Content is written into MediaWiki
# with the maintenance scripts so link tables, search index and recent changes
# stay consistent.
#
# Credentials for Wiki.js come from apps/wiki/.env if present, otherwise from
# the db: block of apps/wiki/config.yml.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEDIAWIKI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MEDIAWIKI_DIR/../.." && pwd)"
APPS_ROOT="$REPO_ROOT/apps"

WIKI_DIR="$APPS_ROOT/wiki"
PG_COMPOSE="$APPS_ROOT/postgresql/docker-compose.yml"
MW_COMPOSE="$MEDIAWIKI_DIR/docker-compose.yml"
WORK_DIR="$REPO_ROOT/run/mediawiki/wikijs-migration"

LOCALE=en
PREFIX=""
USE_TITLES=0
INCLUDE_UNPUBLISHED=0
MW_USER=""
SUMMARY="Imported from Wiki.js"
DO_ASSETS=0
DO_EXPORT=1
DO_IMPORT=1
FIX_LINKS=1
DRY_RUN=0
PANDOC_IMAGE="${PANDOC_IMAGE:-pandoc/core:latest}"
MARKDOWN_FORMAT="${MARKDOWN_FORMAT:-gfm}"

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [options]

Migrates Wiki.js pages into MediaWiki. Both services and PostgreSQL must be
running, and MediaWiki must already be installed (LocalSettings.php in place).

Options:
  --locale CODE         Wiki.js locale to migrate (default: $LOCALE)
  --prefix TEXT         Prepend TEXT to every MediaWiki title, e.g. "Wiki:"
  --titles              Title pages from the Wiki.js title column instead of
                        deriving titles from the page path
  --include-unpublished Also migrate pages Wiki.js has not published
  --assets              Also export Wiki.js assets and import them as files
  --user NAME           Attribute edits to an existing MediaWiki account
                        (default: the MediaWiki maintenance system user)
  --summary TEXT        Edit summary (default: "$SUMMARY")
  --no-fix-links        Leave Wiki.js internal links as external-style links
  --work-dir DIR        Export directory (default: $WORK_DIR)
  --export-only         Export and convert, but do not write to MediaWiki
  --import-only         Import a previous export from the work directory
  --dry-run             Report the title mapping and exit
  -h, --help            This message

Environment:
  MARKDOWN_FORMAT       Pandoc input format for markdown pages (default: $MARKDOWN_FORMAT)
  PANDOC_IMAGE          Image used when pandoc is not installed on the host
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --locale) LOCALE="$2"; shift 2 ;;
        --prefix) PREFIX="$2"; shift 2 ;;
        --titles) USE_TITLES=1; shift ;;
        --include-unpublished) INCLUDE_UNPUBLISHED=1; shift ;;
        --assets) DO_ASSETS=1; shift ;;
        --user) MW_USER="$2"; shift 2 ;;
        --summary) SUMMARY="$2"; shift 2 ;;
        --no-fix-links) FIX_LINKS=0; shift ;;
        --work-dir) WORK_DIR="$2"; shift 2 ;;
        --export-only) DO_IMPORT=0; shift ;;
        --import-only) DO_EXPORT=0; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

die() {
    echo "Error: $*" >&2
    exit 1
}

SRC_DIR="$WORK_DIR/src"
WIKITEXT_DIR="$WORK_DIR/wikitext"
ASSET_DIR="$WORK_DIR/assets"
MANIFEST="$WORK_DIR/manifest.tsv"
LINK_RULES="$WORK_DIR/links.sed"

case "$LOCALE" in
    [a-zA-Z][a-zA-Z]|[a-zA-Z][a-zA-Z]-[a-zA-Z][a-zA-Z]) ;;
    *) die "locale '$LOCALE' is not a Wiki.js locale code (e.g. en, en-us)" ;;
esac

# ── Wiki.js credentials ──────────────────────────────────────────────────────

# Value of KEY from a shell-style .env file, without executing the file.
env_value() {
    local file="$1" key="$2" line value
    [ -f "$file" ] || return 1
    line=$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}=" "$file" | tail -n 1)
    [ -n "$line" ] || return 1
    value=${line#*=}
    value=${value%$'\r'}
    case "$value" in
        \"*\") value=${value#\"}; value=${value%\"} ;;
        \'*\') value=${value#\'}; value=${value%\'} ;;
    esac
    printf '%s' "$value"
}

# Value of KEY from the top-level db: block of a Wiki.js config.yml.
yaml_db_value() {
    local file="$1" key="$2"
    [ -f "$file" ] || return 1
    awk -v key="$key" -v q="'" '
        /^[^[:space:]#]/ { in_db = ($0 ~ /^db:[[:space:]]*$/); next }
        in_db {
            line = $0
            if (match(line, "^[[:space:]]+" key ":[[:space:]]*")) {
                v = substr(line, RLENGTH + 1)
                # A quoted value ends at its closing quote; an unquoted one
                # ends at a trailing comment. Passwords may contain "#".
                if (substr(v, 1, 1) == "\"" || substr(v, 1, 1) == q) {
                    quote = substr(v, 1, 1)
                    v = substr(v, 2)
                    if (index(v, quote) > 0) { v = substr(v, 1, index(v, quote) - 1) }
                } else {
                    sub(/[[:space:]]+#.*/, "", v)
                    gsub(/[[:space:]]+$/, "", v)
                }
                print v
                exit
            }
        }
    ' "$file"
}

WIKI_ENV="$WIKI_DIR/.env"
WIKI_CONFIG="$WIKI_DIR/config.yml"

if [ -f "$WIKI_ENV" ]; then
    CRED_SOURCE="$WIKI_ENV"
    DB_TYPE=$(env_value "$WIKI_ENV" DB_TYPE || echo postgres)
    DB_HOST=$(env_value "$WIKI_ENV" DB_HOST || echo postgresql)
    DB_PORT=$(env_value "$WIKI_ENV" DB_PORT || echo 5432)
    DB_USER=$(env_value "$WIKI_ENV" DB_USER || echo "")
    DB_PASS=$(env_value "$WIKI_ENV" DB_PASS || echo "")
    DB_NAME=$(env_value "$WIKI_ENV" DB_NAME || echo "")
elif [ -f "$WIKI_CONFIG" ]; then
    CRED_SOURCE="$WIKI_CONFIG"
    DB_TYPE=$(yaml_db_value "$WIKI_CONFIG" type)
    DB_HOST=$(yaml_db_value "$WIKI_CONFIG" host)
    DB_PORT=$(yaml_db_value "$WIKI_CONFIG" port)
    DB_USER=$(yaml_db_value "$WIKI_CONFIG" user)
    DB_PASS=$(yaml_db_value "$WIKI_CONFIG" pass)
    DB_NAME=$(yaml_db_value "$WIKI_CONFIG" db)
else
    die "no Wiki.js credentials: neither $WIKI_ENV nor $WIKI_CONFIG exists"
fi

: "${DB_TYPE:=postgres}"
: "${DB_HOST:=postgresql}"
: "${DB_PORT:=5432}"

[ "$DB_TYPE" = "postgres" ] || die "Wiki.js database type is '$DB_TYPE'; this script only handles postgres"
[ -n "$DB_USER" ] || die "no Wiki.js database user found in $CRED_SOURCE"
[ -n "$DB_NAME" ] || die "no Wiki.js database name found in $CRED_SOURCE"

# ── Container plumbing ───────────────────────────────────────────────────────

# Queries are passed with -c, so stdin is closed: "docker compose exec -T"
# would otherwise swallow whatever the caller is reading from.
psql_q() {
    docker compose -f "$PG_COMPOSE" exec -T -e PGPASSWORD="$DB_PASS" postgresql \
        psql -X -q -A -t -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@" < /dev/null
}

mw_exec() {
    docker compose -f "$MW_COMPOSE" exec -T mediawiki "$@"
}

MW_RUNNER=""
mw_maint() {
    local script="$1"; shift
    if [ "$MW_RUNNER" = "run" ]; then
        mw_exec php maintenance/run.php "$script" "$@"
    else
        mw_exec php "maintenance/$script.php" "$@"
    fi
}

if command -v pandoc > /dev/null 2>&1; then
    pandoc_run() { pandoc "$@"; }
else
    pandoc_run() { docker run --rm -i "$PANDOC_IMAGE" "$@"; }
fi

require_postgresql() {
    docker compose -f "$PG_COMPOSE" ps postgresql 2>/dev/null | grep -q 'Up' \
        || die "postgresql container is not running"
    psql_q -c 'SELECT 1;' > /dev/null \
        || die "cannot connect to Wiki.js database '$DB_NAME' as '$DB_USER' (credentials from $CRED_SOURCE)"
}

require_mediawiki() {
    docker compose -f "$MW_COMPOSE" ps mediawiki 2>/dev/null | grep -q 'Up' \
        || die "mediawiki container is not running"
    mw_exec test -f LocalSettings.php \
        || die "MediaWiki is not installed yet: no LocalSettings.php in the container (see README)"
    if mw_exec test -f maintenance/run.php; then
        MW_RUNNER=run
    else
        MW_RUNNER=direct
    fi
}

# ── Titles ───────────────────────────────────────────────────────────────────

# guides/laser-cutter -> Guides/Laser cutter
title_from_path() {
    local path="$1" out="" seg
    local IFS='/'
    local -a segments
    read -ra segments <<< "$path"
    for seg in "${segments[@]}"; do
        [ -n "$seg" ] || continue
        seg=${seg//-/ }
        seg=${seg//_/ }
        [ -n "$out" ] && out="$out/"
        out="$out$(printf '%s' "${seg:0:1}" | tr '[:lower:]' '[:upper:]')${seg:1}"
    done
    printf '%s' "$out"
}

regex_escape() { printf '%s' "$1" | sed 's/[][\.*^$]/\\&/g'; }
repl_escape() { printf '%s' "$1" | sed 's/[\&]/\\&/g'; }

# sed -i, without depending on the GNU spelling of it.
edit_file() {
    local file="$1"; shift
    local tmp="$file.tmp"
    if sed "$@" "$file" > "$tmp"; then
        mv "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

# ── Export ───────────────────────────────────────────────────────────────────

build_manifest() {
    local where="\"localeCode\" = '$LOCALE'"
    [ "$INCLUDE_UNPUBLISHED" -eq 1 ] || where="$where AND \"isPublished\" = true"

    local rows
    rows=$(psql_q -F $'\t' -c \
        "SELECT id, \"contentType\", path, title FROM pages WHERE $where ORDER BY id;") \
        || die "failed to list Wiki.js pages"

    : > "$MANIFEST"
    local id contenttype path title mw_title
    while IFS=$'\t' read -r id contenttype path title; do
        [ -n "${id:-}" ] || continue
        if [ "$USE_TITLES" -eq 1 ] && [ -n "$title" ]; then
            mw_title="$title"
        else
            mw_title=$(title_from_path "$path")
        fi
        [ -n "$mw_title" ] || mw_title="$title"
        printf '%s\t%s\t%s\t%s%s\n' "$id" "$contenttype" "$path" "$PREFIX" "$mw_title" >> "$MANIFEST"
    done <<< "$rows"

    [ -s "$MANIFEST" ] || die "no pages found for locale '$LOCALE'"
}

# Pandoc turns a Wiki.js link such as [text](/guides/laser-cutter) into
# [[guides/laser-cutter|text]], which points at a MediaWiki page that does not
# exist. Retarget those links at the migrated titles.
build_link_rules() {
    local id contenttype path mw_title epath etitle
    : > "$LINK_RULES"
    while IFS=$'\t' read -r id contenttype path mw_title; do
        # "%" delimits the rules below, and a path with regex metacharacters
        # would need escaping BRE makes ambiguous; leave those links alone.
        [[ "$path" =~ ^[A-Za-z0-9/_.-]+$ ]] || continue
        case "$mw_title" in *%*) continue ;; esac
        epath=$(regex_escape "$path")
        etitle=$(repl_escape "$mw_title")
        # [[path]] and [[path|text]] / [[path#anchor|text]]
        printf 's%%\\[\\[/\\{0,1\\}%s\\]\\]%%[[%s]]%%g\n' "$epath" "$etitle" >> "$LINK_RULES"
        printf 's%%\\[\\[/\\{0,1\\}%s\\([|#]\\)%%[[%s\\1%%g\n' "$epath" "$etitle" >> "$LINK_RULES"
    done < "$MANIFEST"
}

export_pages() {
    rm -rf "$SRC_DIR" "$WIKITEXT_DIR"
    mkdir -p "$SRC_DIR" "$WIKITEXT_DIR"

    # The manifest is read on fd 3 so that the docker commands below cannot
    # consume it.
    local id contenttype path mw_title from converted=0 skipped=0
    while IFS=$'\t' read -r id contenttype path mw_title <&3; do
        case "$contenttype" in
            markdown) from="$MARKDOWN_FORMAT" ;;
            html) from=html ;;
            *)
                echo "  skipping $path: unsupported content type '$contenttype'"
                skipped=$((skipped + 1))
                continue
                ;;
        esac

        if ! psql_q -c "SELECT content FROM pages WHERE id = $id;" > "$SRC_DIR/$id.src"; then
            echo "  failed to export $path"
            skipped=$((skipped + 1))
            continue
        fi

        if ! pandoc_run --from="$from" --to=mediawiki --wrap=preserve \
            < "$SRC_DIR/$id.src" > "$WIKITEXT_DIR/$id.wiki"; then
            echo "  failed to convert $path"
            skipped=$((skipped + 1))
            continue
        fi

        # Pandoc keeps the Wiki.js asset path inside File: links; MediaWiki
        # file names are flat.
        edit_file "$WIKITEXT_DIR/$id.wiki" -E 's#\[\[(File|Image):[^]|]*/([^]|/]+)#[[\1:\2#g'

        # MediaWiki generates its own heading anchors, so pandoc's are noise.
        edit_file "$WIKITEXT_DIR/$id.wiki" -E '/^<span id="[^"]*"><\/span>$/d'

        if [ "$FIX_LINKS" -eq 1 ]; then
            edit_file "$WIKITEXT_DIR/$id.wiki" -f "$LINK_RULES"
        fi

        converted=$((converted + 1))
        echo "  $path -> $mw_title"
    done 3< "$MANIFEST"

    echo ""
    echo "Converted $converted page(s), skipped $skipped."
}

export_assets() {
    rm -rf "$ASSET_DIR"
    mkdir -p "$ASSET_DIR"

    local rows id filename exported=0
    rows=$(psql_q -F $'\t' -c 'SELECT id, filename FROM assets ORDER BY id;') \
        || die "failed to list Wiki.js assets"

    while IFS=$'\t' read -r id filename <&3; do
        [ -n "${id:-}" ] || continue
        filename=$(basename "$filename")
        if [ -e "$ASSET_DIR/$filename" ]; then
            echo "  name collision, skipping asset $id ($filename)"
            continue
        fi
        if psql_q -c "SELECT encode(data, 'base64') FROM \"assetData\" WHERE id = $id;" \
            | base64 -d > "$ASSET_DIR/$filename"; then
            exported=$((exported + 1))
        else
            echo "  failed to export asset $id ($filename)"
            rm -f "$ASSET_DIR/$filename"
        fi
    done 3<<< "$rows"

    echo "Exported $exported asset(s)."
}

# ── Import ───────────────────────────────────────────────────────────────────

import_pages() {
    local id contenttype path mw_title imported=0 failed=0
    while IFS=$'\t' read -r id contenttype path mw_title <&3; do
        [ -f "$WIKITEXT_DIR/$id.wiki" ] || continue
        local -a args=(-s "$SUMMARY" --bot)
        [ -n "$MW_USER" ] && args+=(-u "$MW_USER")
        if mw_maint edit "${args[@]}" "$mw_title" < "$WIKITEXT_DIR/$id.wiki" > /dev/null; then
            imported=$((imported + 1))
            echo "  $mw_title"
        else
            failed=$((failed + 1))
            echo "  FAILED: $mw_title (from $path)"
        fi
    done 3< "$MANIFEST"

    echo ""
    echo "Imported $imported page(s), $failed failure(s)."
}

import_assets() {
    [ -d "$ASSET_DIR" ] || return 0
    mw_exec mkdir -p /tmp/wikijs-assets || die "could not create import directory in the container"
    docker cp "$ASSET_DIR/." mediawiki:/tmp/wikijs-assets/ || die "could not copy assets into the container"

    local -a args=(--comment="$SUMMARY" --skip-dupes)
    [ -n "$MW_USER" ] && args+=(--user="$MW_USER")
    mw_maint importImages "${args[@]}" /tmp/wikijs-assets
    mw_exec rm -rf /tmp/wikijs-assets
}

# ── Run ──────────────────────────────────────────────────────────────────────

mkdir -p "$WORK_DIR"

echo "Wiki.js credentials: $CRED_SOURCE"
echo "Database:            $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo "Work directory:      $WORK_DIR"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    require_postgresql
    build_manifest
    echo "Title mapping (locale $LOCALE):"
    while IFS=$'\t' read -r id contenttype path mw_title; do
        printf '  %-50s %s\n' "$path" "$mw_title"
    done < "$MANIFEST"
    echo ""
    echo "Dry run: nothing was written to MediaWiki."
    exit 0
fi

if [ "$DO_EXPORT" -eq 1 ]; then
    require_postgresql
    echo "==> Exporting pages from Wiki.js..."
    build_manifest
    [ "$FIX_LINKS" -eq 1 ] && build_link_rules
    export_pages
    if [ "$DO_ASSETS" -eq 1 ]; then
        echo ""
        echo "==> Exporting assets from Wiki.js..."
        export_assets
    fi
else
    [ -s "$MANIFEST" ] || die "no manifest in $WORK_DIR; run without --import-only first"
fi

if [ "$DO_IMPORT" -eq 0 ]; then
    echo ""
    echo "Export complete. Review $WIKITEXT_DIR, then import with:"
    echo "  $0 --import-only --work-dir $WORK_DIR"
    exit 0
fi

require_mediawiki

echo ""
echo "==> Importing pages into MediaWiki..."
import_pages

if [ "$DO_ASSETS" -eq 1 ]; then
    echo ""
    echo "==> Importing assets into MediaWiki..."
    import_assets
fi

echo ""
echo "Migration complete. Rebuild derived data if anything looks stale:"
echo "  docker compose -f $MW_COMPOSE exec mediawiki php maintenance/run.php rebuildall"
