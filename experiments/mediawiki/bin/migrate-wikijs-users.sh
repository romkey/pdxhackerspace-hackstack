#!/bin/bash
#
# migrate-wikijs-users.sh
# Pre-create MediaWiki accounts for Wiki.js users, so that SSO logins land on
# the right account instead of making duplicates and so that migrate-wikijs.sh
# can credit each page to the person who wrote it.
#
# Passwords are not migrated: every account is created with a throwaway
# password which is then scrambled, leaving the account SSO-only. Accounts are
# adopted by their identity provider on first login, which needs the
# OpenIDConnect extension setting
#     $wgOpenIDConnect_MigrateUsersByEmail = true;
# See the README, including for how to retire a provider later.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEDIAWIKI_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$MEDIAWIKI_DIR/../.." && pwd)"

# shellcheck source=wikijs-lib.sh
. "$SCRIPT_DIR/wikijs-lib.sh"

WORK_DIR="$REPO_ROOT/run/mediawiki/wikijs-migration"
USERNAME_FROM=name
ON_COLLISION=source
GROUP_MAP="Administrators=sysop+bureaucrat"
ACTIVE_ONLY=0
DRY_RUN=0

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [options]

Creates a MediaWiki account for each Wiki.js user, carrying over the display
name, email address and group membership. PostgreSQL and MediaWiki must be
running, and MediaWiki must already be installed.

Wiki.js users who share an email address become one MediaWiki account, since
the email address is what an SSO login is matched on.

Options:
  --username-from name|email  Take user names from the Wiki.js display name, or
                              from the local part of the email address
                              (default: $USERNAME_FROM)
  --on-collision source|number|skip
                              How to separate two users whose names collide:
                              append the identity source, giving for example
                              "John Romkey (slack)"; append a number; or report
                              them and create neither (default: $ON_COLLISION)
  --group-map MAP             Comma-separated Wiki.js group mappings, each one
                              WikiJsGroup=mwgroup[+mwgroup...]
                              (default: $GROUP_MAP)
                              Pass an empty string to migrate no groups.
  --active-only               Skip Wiki.js users marked inactive. They are
                              included by default so that pages they wrote can
                              still be credited to them.
  --work-dir DIR              Where to write the mapping (default: $WORK_DIR)
  --dry-run                   Report the mapping and exit without creating
                              anything
  -h, --help                  This message
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --username-from) USERNAME_FROM="$2"; shift 2 ;;
        --on-collision) ON_COLLISION="$2"; shift 2 ;;
        --group-map) GROUP_MAP="$2"; shift 2 ;;
        --active-only) ACTIVE_ONLY=1; shift ;;
        --work-dir) WORK_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    die "this script needs bash 4 or newer; found ${BASH_VERSION:-unknown}"
fi

case "$USERNAME_FROM" in
    name|email) ;;
    *) die "--username-from must be 'name' or 'email'" ;;
esac
case "$ON_COLLISION" in
    source|number|skip) ;;
    *) die "--on-collision must be 'source', 'number' or 'skip'" ;;
esac

PLAN="$WORK_DIR/users.plan.tsv"
USERS_FILE="$WORK_DIR/users.tsv"

load_wikijs_credentials

# ── Group mapping ────────────────────────────────────────────────────────────

declare -A MW_GROUPS_FOR
UNMAPPED_GROUPS=""

parse_group_map() {
    local entry wikijs_group mw_groups
    local IFS=,
    for entry in $GROUP_MAP; do
        [ -n "$entry" ] || continue
        case "$entry" in
            *=*) ;;
            *) die "bad --group-map entry '$entry'; expected WikiJsGroup=mwgroup" ;;
        esac
        wikijs_group=${entry%%=*}
        mw_groups=${entry#*=}
        MW_GROUPS_FOR["$wikijs_group"]=${mw_groups//+/,}
    done
}
parse_group_map

# Maps one user's pipe-separated Wiki.js groups to MediaWiki groups in
# MAPPED_GROUPS. Sets a global rather than printing, so that groups without a
# mapping can be collected for the report.
MAPPED_GROUPS=""
map_groups() {
    local group out=""
    local IFS='|'
    for group in $1; do
        [ -n "$group" ] || continue
        if [ -n "${MW_GROUPS_FOR[$group]:-}" ]; then
            out="${out:+$out,}${MW_GROUPS_FOR[$group]}"
        else
            UNMAPPED_GROUPS="$UNMAPPED_GROUPS$group"$'\n'
        fi
    done
    MAPPED_GROUPS="$out"
}

# ── Read Wiki.js users ───────────────────────────────────────────────────────

fetch_users() {
    local where='u."isSystem" = false'
    [ "$ACTIVE_ONLY" -eq 0 ] || where="$where AND u.\"isActive\" = true"

    # Wiki.js 2.5 moved the identity provider into authentication.strategyKey
    # and gave it an administrator-chosen display name; before that,
    # users.providerKey held the provider directly.
    local modern="SELECT u.id,
               COALESCE(NULLIF(a.\"displayName\", ''), NULLIF(a.\"strategyKey\", ''), u.\"providerKey\"),
               u.email, u.name, u.\"isActive\",
               COALESCE(string_agg(g.name, '|' ORDER BY g.name), '')
        FROM users u
        LEFT JOIN authentication a ON a.key = u.\"providerKey\"
        LEFT JOIN \"userGroups\" ug ON ug.\"userId\" = u.id
        LEFT JOIN \"groups\" g ON g.id = ug.\"groupId\" AND g.\"isSystem\" = false
        WHERE $where
        GROUP BY u.id, a.\"displayName\", a.\"strategyKey\", u.\"providerKey\", u.email, u.name, u.\"isActive\"
        ORDER BY u.id;"

    local legacy="SELECT u.id, u.\"providerKey\", u.email, u.name, u.\"isActive\",
               COALESCE(string_agg(g.name, '|' ORDER BY g.name), '')
        FROM users u
        LEFT JOIN \"userGroups\" ug ON ug.\"userId\" = u.id
        LEFT JOIN \"groups\" g ON g.id = ug.\"groupId\" AND g.\"isSystem\" = false
        WHERE $where
        GROUP BY u.id, u.\"providerKey\", u.email, u.name, u.\"isActive\"
        ORDER BY u.id;"

    psql_q -F $'\t' -c "$modern" 2>/dev/null || psql_q -F $'\t' -c "$legacy"
}

declare -A ROW_SOURCE ROW_EMAIL ROW_NAME ROW_ACTIVE ROW_GROUPS
declare -a ROW_IDS

read_users() {
    local rows line id label
    rows=$(fetch_users) || die "failed to read Wiki.js users"

    while IFS= read -r line <&3; do
        split_tsv "$line"
        id="${TSV[0]}"
        [ -n "$id" ] || continue
        label=$(source_label "${TSV[1]:-}")
        ROW_IDS+=("$id")
        ROW_SOURCE["$id"]="${label:-unknown}"
        ROW_EMAIL["$id"]="${TSV[2]:-}"
        ROW_NAME["$id"]="${TSV[3]:-}"
        ROW_ACTIVE["$id"]="${TSV[4]:-t}"
        ROW_GROUPS["$id"]="${TSV[5]:-}"
    done 3<<< "$rows"

    [ -n "${ROW_IDS[*]:-}" ] || die "no Wiki.js users found in database '$DB_NAME'"
}

# ── Plan: merge by email, derive names, resolve collisions ───────────────────

declare -A PRIMARY_FOR_EMAIL MEMBERS_FOR_EMAIL GROUPS_FOR_EMAIL
declare -A USERNAME_FOR_EMAIL NOTE_FOR_EMAIL
declare -A NAME_USES
declare -a EMAIL_KEYS

merge_by_email() {
    local id key
    for id in "${ROW_IDS[@]}"; do
        key=$(printf '%s' "${ROW_EMAIL[$id]}" | tr '[:upper:]' '[:lower:]')
        # With no email address SSO can never claim the account, so keep it
        # separate: it exists only so its pages can be credited.
        [ -n "$key" ] || key="(no-email-$id)"

        if [ -z "${PRIMARY_FOR_EMAIL[$key]:-}" ]; then
            PRIMARY_FOR_EMAIL["$key"]="$id"
            EMAIL_KEYS+=("$key")
        fi
        MEMBERS_FOR_EMAIL["$key"]="${MEMBERS_FOR_EMAIL[$key]:+${MEMBERS_FOR_EMAIL[$key]} }$id"
        GROUPS_FOR_EMAIL["$key"]="${GROUPS_FOR_EMAIL[$key]:+${GROUPS_FOR_EMAIL[$key]}|}${ROW_GROUPS[$id]}"
    done
}

base_username_for() {
    local id="$1" raw
    if [ "$USERNAME_FROM" = email ]; then
        raw="${ROW_EMAIL[$id]%%@*}"
        raw="${raw//./ }"
    else
        raw="${ROW_NAME[$id]}"
    fi
    mw_username_from "$raw"
}

assign_usernames() {
    local key id base candidate suffix n
    local -A taken=()

    # First, work out which names more than one account wants.
    for key in "${EMAIL_KEYS[@]}"; do
        id="${PRIMARY_FOR_EMAIL[$key]}"
        if ! base=$(base_username_for "$id"); then
            USERNAME_FOR_EMAIL["$key"]=""
            NOTE_FOR_EMAIL["$key"]="no usable MediaWiki user name from '${ROW_NAME[$id]}'"
            continue
        fi
        USERNAME_FOR_EMAIL["$key"]="$base"
        NAME_USES["$base"]=$(( ${NAME_USES[$base]:-0} + 1 ))
    done

    # Then separate the ones that collide.
    for key in "${EMAIL_KEYS[@]}"; do
        base="${USERNAME_FOR_EMAIL[$key]}"
        [ -n "$base" ] || continue
        id="${PRIMARY_FOR_EMAIL[$key]}"

        if [ "${NAME_USES[$base]}" -le 1 ] && [ -z "${taken[$base]:-}" ]; then
            taken["$base"]=1
            continue
        fi

        if [ "$ON_COLLISION" = skip ]; then
            USERNAME_FOR_EMAIL["$key"]=""
            NOTE_FOR_EMAIL["$key"]="name '$base' is claimed by more than one user"
            continue
        fi

        if [ "$ON_COLLISION" = source ]; then
            candidate="$base (${ROW_SOURCE[$id]})"
        else
            candidate="$base"
        fi

        # Numbering is the fallback for when the suffix is still not unique,
        # such as two same-named users from the same identity source.
        suffix="$candidate"
        n=1
        while [ -n "${taken[$suffix]:-}" ]; do
            n=$(( n + 1 ))
            suffix="$candidate $n"
        done
        taken["$suffix"]=1
        USERNAME_FOR_EMAIL["$key"]="$suffix"
        [ "$suffix" = "$base" ] || NOTE_FOR_EMAIL["$key"]="renamed from '$base', which collided"
    done
}

write_plan() {
    mkdir -p "$WORK_DIR"
    : > "$PLAN"

    local key id note members
    for key in "${EMAIL_KEYS[@]}"; do
        id="${PRIMARY_FOR_EMAIL[$key]}"
        members="${MEMBERS_FOR_EMAIL[$key]}"
        map_groups "${GROUPS_FOR_EMAIL[$key]}"

        note="${NOTE_FOR_EMAIL[$key]:-}"
        case "$members" in
            *' '*) note="${note:+$note; }merged Wiki.js users $members" ;;
        esac
        [ -n "${ROW_EMAIL[$id]}" ] || note="${note:+$note; }no email address, so SSO cannot claim it"
        [ "${ROW_ACTIVE[$id]}" != f ] || note="${note:+$note; }inactive in Wiki.js"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$id" \
            "${ROW_SOURCE[$id]}" \
            "${ROW_EMAIL[$id]}" \
            "${USERNAME_FOR_EMAIL[$key]}" \
            "$MAPPED_GROUPS" \
            "$members" \
            "$note" >> "$PLAN"
    done
}

report_plan() {
    local line id source email username groups members note
    local creating=0 skipped=0 merged=0

    printf '%-30s %-12s %-32s %s\n' "MEDIAWIKI ACCOUNT" "SOURCE" "EMAIL" "GROUPS"
    while IFS= read -r line; do
        split_tsv "$line"
        id="${TSV[0]}" source="${TSV[1]}" email="${TSV[2]}"
        username="${TSV[3]}" groups="${TSV[4]}" members="${TSV[5]}" note="${TSV[6]:-}"

        if [ -z "$username" ]; then
            skipped=$((skipped + 1))
            printf '  SKIPPED  %-44s %s\n' "${email:-(Wiki.js user $id)}" "$note"
            continue
        fi
        creating=$((creating + 1))
        case "$members" in *' '*) merged=$((merged + 1)) ;; esac
        printf '%-30s %-12s %-32s %s\n' "$username" "$source" "$email" "${groups:--}"
        [ -z "$note" ] || printf '  %s\n' "$note"
    done < "$PLAN"

    echo ""
    echo "$creating account(s) to create, $merged of them merged by email, $skipped skipped."

    if [ -n "$UNMAPPED_GROUPS" ]; then
        echo ""
        echo "Wiki.js groups with no mapping, granting no MediaWiki groups:"
        printf '%s' "$UNMAPPED_GROUPS" | sort -u | sed 's/^/  /'
        echo "Map them with --group-map if they should grant rights."
    fi
}

# ── Create the accounts ──────────────────────────────────────────────────────

# Only ever used to satisfy createAndPromote, then thrown away and scrambled.
random_password() {
    if command -v pwgen > /dev/null 2>&1; then
        pwgen -s 32 1
    elif command -v openssl > /dev/null 2>&1; then
        openssl rand -base64 24 | tr -d '\n'
    else
        head -c 24 /dev/urandom | base64 | tr -d '\n'
    fi
}

create_accounts() {
    local line id source email username groups members member out
    local created=0 failed=0
    : > "$USERS_FILE"

    while IFS= read -r line <&3; do
        split_tsv "$line"
        id="${TSV[0]}" source="${TSV[1]}" email="${TSV[2]}"
        username="${TSV[3]}" groups="${TSV[4]}" members="${TSV[5]}"
        [ -n "$username" ] || continue

        local -a args=(--force)
        [ -z "$groups" ] || args+=(--custom-groups="$groups")

        if ! out=$(mw_maint createAndPromote "${args[@]}" "$username" "$(random_password)" 2>&1 < /dev/null); then
            echo "  FAILED to create $username: $(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"
            failed=$((failed + 1))
            continue
        fi
        case "$out" in
            *'is not a valid group'*)
                echo "  $username: $(printf '%s' "$out" | grep 'is not a valid group' | tr '\n' ' ')" ;;
        esac

        # Records the address, marks it authenticated, and scrambles the
        # password set above so the account can only be used through SSO.
        if [ -n "$email" ] && ! out=$(mw_maint resetUserEmail "$username" "$email" 2>&1 < /dev/null); then
            echo "  created $username but could not set its email: $(printf '%s' "$out" | tail -n 2 | tr '\n' ' ')"
            failed=$((failed + 1))
            continue
        fi

        # One row per Wiki.js user id, so that page attribution can resolve any
        # author, including those merged into a shared account.
        for member in $members; do
            printf '%s\t%s\t%s\t%s\t%s\n' "$member" "$source" "$email" "$username" "$groups" >> "$USERS_FILE"
        done

        created=$((created + 1))
        echo "  $username <${email:-no email}>${groups:+ [$groups]}"
    done 3< "$PLAN"

    echo ""
    echo "Created or updated $created account(s), $failed failure(s)."
    echo "Mapping for page attribution: $USERS_FILE"
}

# ── Run ──────────────────────────────────────────────────────────────────────

echo "Wiki.js credentials: $CRED_SOURCE"
echo "Database:            $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
echo "Work directory:      $WORK_DIR"
echo ""

require_postgresql
read_users
merge_by_email
assign_usernames
write_plan
report_plan

if [ "$DRY_RUN" -eq 1 ]; then
    echo ""
    echo "Dry run: no accounts were created. Plan written to $PLAN"
    exit 0
fi

require_mediawiki

echo ""
echo "==> Creating MediaWiki accounts..."
create_accounts

cat <<EOF

These accounts have no usable password. For a login to adopt one of them
instead of creating a duplicate, MediaWiki needs
    \$wgOpenIDConnect_MigrateUsersByEmail = true;
and the person must not have signed in through SSO already.
EOF
