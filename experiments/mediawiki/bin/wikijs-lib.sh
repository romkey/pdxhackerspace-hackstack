# shellcheck shell=bash
#
# wikijs-lib.sh
# Shared helpers for the Wiki.js -> MediaWiki migration scripts in this
# directory. Meant to be sourced, not run.
#
# The calling script must set MEDIAWIKI_DIR and REPO_ROOT before sourcing:
#   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   MEDIAWIKI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
#   REPO_ROOT="$(cd "$MEDIAWIKI_DIR/../.." && pwd)"
#   . "$SCRIPT_DIR/wikijs-lib.sh"

APPS_ROOT="$REPO_ROOT/apps"
WIKI_DIR="${WIKI_DIR:-$APPS_ROOT/wiki}"
PG_COMPOSE="${PG_COMPOSE:-$APPS_ROOT/postgresql/docker-compose.yml}"
MW_COMPOSE="${MW_COMPOSE:-$MEDIAWIKI_DIR/docker-compose.yml}"

die() {
    echo "Error: $*" >&2
    exit 1
}

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

# Sets CRED_SOURCE and DB_TYPE / DB_HOST / DB_PORT / DB_USER / DB_PASS / DB_NAME.
load_wikijs_credentials() {
    local wiki_env="$WIKI_DIR/.env"
    local wiki_config="$WIKI_DIR/config.yml"

    if [ -f "$wiki_env" ]; then
        CRED_SOURCE="$wiki_env"
        DB_TYPE=$(env_value "$wiki_env" DB_TYPE || echo postgres)
        DB_HOST=$(env_value "$wiki_env" DB_HOST || echo postgresql)
        DB_PORT=$(env_value "$wiki_env" DB_PORT || echo 5432)
        DB_USER=$(env_value "$wiki_env" DB_USER || echo "")
        DB_PASS=$(env_value "$wiki_env" DB_PASS || echo "")
        DB_NAME=$(env_value "$wiki_env" DB_NAME || echo "")
    elif [ -f "$wiki_config" ]; then
        CRED_SOURCE="$wiki_config"
        DB_TYPE=$(yaml_db_value "$wiki_config" type)
        DB_HOST=$(yaml_db_value "$wiki_config" host)
        DB_PORT=$(yaml_db_value "$wiki_config" port)
        DB_USER=$(yaml_db_value "$wiki_config" user)
        DB_PASS=$(yaml_db_value "$wiki_config" pass)
        DB_NAME=$(yaml_db_value "$wiki_config" db)
    else
        die "no Wiki.js credentials: neither $wiki_env nor $wiki_config exists"
    fi

    : "${DB_TYPE:=postgres}"
    : "${DB_HOST:=postgresql}"
    : "${DB_PORT:=5432}"

    [ "$DB_TYPE" = "postgres" ] || die "Wiki.js database type is '$DB_TYPE'; these scripts only handle postgres"
    [ -n "$DB_USER" ] || die "no Wiki.js database user found in $CRED_SOURCE"
    [ -n "$DB_NAME" ] || die "no Wiki.js database name found in $CRED_SOURCE"
}

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

# ── Text helpers ─────────────────────────────────────────────────────────────

# Splits a tab-separated line into the TSV array.
#
# "IFS=$'\t' read -r a b c" cannot be used for this: a tab in IFS counts as
# whitespace, so runs of tabs collapse into one separator and every field after
# an empty one shifts a place left. Empty fields are normal here, since users
# may have no groups and pages no author.
split_tsv() {
    local line="$1"
    TSV=()
    while true; do
        TSV+=("${line%%$'\t'*}")
        case "$line" in
            *$'\t'*) line="${line#*$'\t'}" ;;
            *) return 0 ;;
        esac
    done
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

# Turns a Wiki.js display name into a name MediaWiki will accept, or fails.
mw_username_from() {
    local name="$1"
    name="${name//_/ }"
    # Characters MediaWiki rejects in titles, plus "@" and ":" which it
    # rejects or reserves in user names.
    name=$(printf '%s' "$name" | tr -d '#<>[]|{}@:/=' | tr -s '[:space:]' ' ')
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [ -n "$name" ] || return 1
    # MediaWiki cannot name an account after an IP address.
    case "$name" in
        [0-9]*.[0-9]*.[0-9]*.[0-9]*) return 1 ;;
    esac
    # MediaWiki capitalizes the first letter itself; do it here so the mapping
    # we record matches what the wiki will store.
    name="$(printf '%s' "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
    # User names are limited to 255 bytes.
    printf '%s' "${name:0:200}"
}

# "Authentik SSO" -> authentik-sso, for use as a disambiguating suffix.
source_label() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-'
}
