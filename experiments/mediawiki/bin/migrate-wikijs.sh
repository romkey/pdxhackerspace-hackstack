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

# shellcheck source=wikijs-lib.sh
. "$SCRIPT_DIR/wikijs-lib.sh"

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
ATTRIBUTE=0
ATTRIBUTE_BY=author
USERS_FILE=""
BOT_EDITS=1
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
  --attribute           Credit each page to the MediaWiki account of its
                        Wiki.js author, using the mapping written by
                        migrate-wikijs-users.sh
  --attribute-by author|creator
                        Whether to credit the last editor of the page or the
                        person who created it (default: $ATTRIBUTE_BY)
  --users-file PATH     Account mapping to use with --attribute
                        (default: users.tsv in the work directory)
  --user NAME           Account for pages with no attribution, or for every
                        page without --attribute (default: the MediaWiki
                        maintenance system user)
  --summary TEXT        Edit summary (default: "$SUMMARY")
  --no-bot              Do not mark the imported edits as bot edits, so they
                        appear in Recent changes by default
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
        --attribute) ATTRIBUTE=1; shift ;;
        --attribute-by) ATTRIBUTE_BY="$2"; shift 2 ;;
        --users-file) USERS_FILE="$2"; shift 2 ;;
        --user) MW_USER="$2"; shift 2 ;;
        --summary) SUMMARY="$2"; shift 2 ;;
        --no-bot) BOT_EDITS=0; shift ;;
        --no-fix-links) FIX_LINKS=0; shift ;;
        --work-dir) WORK_DIR="$2"; shift 2 ;;
        --export-only) DO_IMPORT=0; shift ;;
        --import-only) DO_EXPORT=0; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

SRC_DIR="$WORK_DIR/src"
WIKITEXT_DIR="$WORK_DIR/wikitext"
ASSET_DIR="$WORK_DIR/assets"
MANIFEST="$WORK_DIR/manifest.tsv"
LINK_RULES="$WORK_DIR/links.sed"
: "${USERS_FILE:=$WORK_DIR/users.tsv}"

case "$LOCALE" in
    [a-zA-Z][a-zA-Z]|[a-zA-Z][a-zA-Z]-[a-zA-Z][a-zA-Z]) ;;
    *) die "locale '$LOCALE' is not a Wiki.js locale code (e.g. en, en-us)" ;;
esac

case "$ATTRIBUTE_BY" in
    author|creator) ;;
    *) die "--attribute-by must be 'author' or 'creator'" ;;
esac

if [ "$ATTRIBUTE" -eq 1 ] && [ ! -s "$USERS_FILE" ]; then
    die "--attribute needs the account mapping at $USERS_FILE; run migrate-wikijs-users.sh first"
fi

load_wikijs_credentials

if command -v pandoc > /dev/null 2>&1; then
    pandoc_run() { pandoc "$@"; }
else
    pandoc_run() { docker run --rm -i "$PANDOC_IMAGE" "$@"; }
fi

# ── Titles and authors ───────────────────────────────────────────────────────

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

# MediaWiki account for a Wiki.js user id, from the mapping that
# migrate-wikijs-users.sh writes. Empty when the user was not migrated.
mw_user_for_wikijs_id() {
    local uid="${1:-}"
    [ -n "$uid" ] && [ "$uid" != 0 ] || return 0
    awk -F'\t' -v uid="$uid" '$1 == uid { print $4; exit }' "$USERS_FILE"
}

# ── Export ───────────────────────────────────────────────────────────────────

build_manifest() {
    local where="\"localeCode\" = '$LOCALE'"
    [ "$INCLUDE_UNPUBLISHED" -eq 1 ] || where="$where AND \"isPublished\" = true"

    local rows
    rows=$(psql_q -F $'\t' -c \
        "SELECT id, \"contentType\", path, title,
                COALESCE(\"authorId\", 0), COALESCE(\"creatorId\", 0)
         FROM pages WHERE $where ORDER BY id;") \
        || die "failed to list Wiki.js pages"

    : > "$MANIFEST"
    local line id contenttype path title author_id creator_id mw_title mw_author
    while IFS= read -r line <&3; do
        split_tsv "$line"
        id="${TSV[0]}" contenttype="${TSV[1]:-}" path="${TSV[2]:-}"
        title="${TSV[3]:-}" author_id="${TSV[4]:-0}" creator_id="${TSV[5]:-0}"
        [ -n "$id" ] || continue
        if [ "$USE_TITLES" -eq 1 ] && [ -n "$title" ]; then
            mw_title="$title"
        else
            mw_title=$(title_from_path "$path")
        fi
        [ -n "$mw_title" ] || mw_title="$title"

        mw_author=""
        if [ "$ATTRIBUTE" -eq 1 ]; then
            if [ "$ATTRIBUTE_BY" = creator ]; then
                mw_author=$(mw_user_for_wikijs_id "$creator_id")
            else
                mw_author=$(mw_user_for_wikijs_id "$author_id")
            fi
        fi

        printf '%s\t%s\t%s\t%s%s\t%s\n' \
            "$id" "$contenttype" "$path" "$PREFIX" "$mw_title" "$mw_author" >> "$MANIFEST"
    done 3<<< "$rows"

    [ -s "$MANIFEST" ] || die "no pages found for locale '$LOCALE'"
}

# Pandoc turns a Wiki.js link such as [text](/guides/laser-cutter) into
# [[guides/laser-cutter|text]], which points at a MediaWiki page that does not
# exist. Retarget those links at the migrated titles.
build_link_rules() {
    local line path mw_title epath etitle
    : > "$LINK_RULES"
    while IFS= read -r line; do
        split_tsv "$line"
        path="${TSV[2]:-}" mw_title="${TSV[3]:-}"
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
    local line id contenttype path mw_title from converted=0 skipped=0
    while IFS= read -r line <&3; do
        split_tsv "$line"
        id="${TSV[0]}" contenttype="${TSV[1]:-}" path="${TSV[2]:-}" mw_title="${TSV[3]:-}"
        [ -n "$id" ] || continue

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

    local rows line id filename exported=0
    rows=$(psql_q -F $'\t' -c 'SELECT id, filename FROM assets ORDER BY id;') \
        || die "failed to list Wiki.js assets"

    while IFS= read -r line <&3; do
        split_tsv "$line"
        id="${TSV[0]}" filename="${TSV[1]:-}"
        [ -n "$id" ] && [ -n "$filename" ] || continue
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
    local line id path mw_title mw_author author imported=0 failed=0 unattributed=0
    while IFS= read -r line <&3; do
        split_tsv "$line"
        id="${TSV[0]}" path="${TSV[2]:-}" mw_title="${TSV[3]:-}" mw_author="${TSV[4]:-}"
        [ -n "$id" ] && [ -f "$WIKITEXT_DIR/$id.wiki" ] || continue

        local -a args=(-s "$SUMMARY")
        [ "$BOT_EDITS" -eq 1 ] && args+=(--bot)

        # edit.php creates the account named by -u if it does not exist, so
        # only names from the migrated account mapping are used here.
        author="${mw_author:-$MW_USER}"
        [ -z "$author" ] || args+=(-u "$author")
        if [ "$ATTRIBUTE" -eq 1 ] && [ -z "$mw_author" ]; then
            unattributed=$((unattributed + 1))
        fi

        if mw_maint edit "${args[@]}" "$mw_title" < "$WIKITEXT_DIR/$id.wiki" > /dev/null; then
            imported=$((imported + 1))
            echo "  $mw_title${author:+ (as $author)}"
        else
            failed=$((failed + 1))
            echo "  FAILED: $mw_title (from $path)"
        fi
    done 3< "$MANIFEST"

    echo ""
    echo "Imported $imported page(s), $failed failure(s)."
    [ "$unattributed" -eq 0 ] || echo "$unattributed page(s) had no migrated author and fell back to the default user."
}

import_assets() {
    local exported found ignored out status
    exported=$(find "$ASSET_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "${exported:-0}" -eq 0 ]; then
        echo "  no exported files in $ASSET_DIR; nothing to import"
        return 0
    fi

    mw_exec mkdir -p /tmp/wikijs-assets || die "could not create import directory in the container"
    docker cp "$ASSET_DIR/." mediawiki:/tmp/wikijs-assets/ || die "could not copy assets into the container"

    local -a args=(--comment="$SUMMARY" --skip-dupes)
    [ -n "$MW_USER" ] && args+=(--user="$MW_USER")

    out=$(mw_maint importImages "${args[@]}" /tmp/wikijs-assets 2>&1 < /dev/null)
    status=$?
    printf '%s\n' "$out"
    mw_exec rm -rf /tmp/wikijs-assets

    # importImages only looks at extensions in $wgFileExtensions, and says
    # nothing about the files it therefore never considered.
    found=$(printf '%s' "$out" | awk -F': ' '/^Found: /{print $2; exit}')
    ignored=$(( exported - ${found:-0} ))
    if [ "$ignored" -gt 0 ]; then
        echo ""
        echo "$ignored of $exported exported file(s) were left out because their extension"
        echo "is not in \$wgFileExtensions. PDFs and CAD files are not allowed by default;"
        echo "add what you need to LocalSettings.php and re-run with --import-only --assets."
    fi
    if [ "$status" -ne 0 ]; then
        echo ""
        echo "importImages reported failures. If nothing was added at all, check that"
        echo "\$wgEnableUploads is true in LocalSettings.php."
    fi
}

# ── Run ──────────────────────────────────────────────────────────────────────

mkdir -p "$WORK_DIR"

echo "Wiki.js credentials: $CRED_SOURCE"
echo "Database:            $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo "Work directory:      $WORK_DIR"
[ "$ATTRIBUTE" -eq 0 ] || echo "Attribution:         by $ATTRIBUTE_BY, from $USERS_FILE"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    require_postgresql
    build_manifest
    echo "Title mapping (locale $LOCALE):"
    while IFS= read -r line; do
        split_tsv "$line"
        if [ "$ATTRIBUTE" -eq 1 ]; then
            printf '  %-44s %-30s %s\n' "${TSV[2]}" "${TSV[3]}" "${TSV[4]:-(default user)}"
        else
            printf '  %-50s %s\n' "${TSV[2]}" "${TSV[3]}"
        fi
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
else
    echo ""
    echo "Wiki.js uploads were not migrated: --assets was not given. Images in the"
    echo "imported pages will be red links until the files are in MediaWiki."
fi

echo ""
echo "Migration complete. Rebuild derived data if anything looks stale:"
echo "  docker compose -f $MW_COMPOSE exec mediawiki php maintenance/run.php rebuildall"
