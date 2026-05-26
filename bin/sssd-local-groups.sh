#!/bin/bash
# Add SSSD/LDAP users to local supplementary groups on login.
# Invoked by pam_exec; PAM_USER is set by PAM.

set -u

LOGFILE=/var/log/sssd-local-groups.log
LOCAL_GROUPS=(docker hackstack)

# pam_exec sets PAM_USER; bail if missing.
USER="${PAM_USER:-}"
[ -z "$USER" ] && exit 0

# Only act on session open, not close.
[ "${PAM_TYPE:-}" = "open_session" ] || exit 0

# Skip local users — only touch users that resolve via SSSD.
# getent passwd <user> | check the source: a quick way is to see if the
# user exists in /etc/passwd directly.
if grep -q "^${USER}:" /etc/passwd; then
    exit 0
fi

# Confirm the user actually resolves (via SSSD).
id -u "$USER" >/dev/null 2>&1 || exit 0

for grp in "${LOCAL_GROUPS[@]}"; do
    # Skip if group doesn't exist on this host.
    getent group "$grp" >/dev/null 2>&1 || continue

    # Skip if user already a member.
    if id -nG "$USER" | tr ' ' '\n' | grep -qx "$grp"; then
        continue
    fi

    /usr/sbin/usermod -a -G "$grp" "$USER" \
        && echo "$(date -Iseconds) added $USER to $grp" >> "$LOGFILE"
done

exit 0