#!/bin/sh
#
# debian-ldap-login.sh
# Idempotent-ish setup for LDAP logins on Debian via SSSD against Authentik LDAP.
#
# Requires:
#   - LDAP_BIND_PASSWORD in the environment (password for ldap_default_bind_dn).
# Optional:
#   - LDAP_TLS_CACERT - path to CA PEM for ldaps:// (default: /etc/ssl/certs/your-ca.pem).
#
# Ensure the CA file exists and that the host can resolve/connect to LDAP
# (e.g. authentik-ldap in Docker may need /etc/hosts or LAN DNS).
#
# ldap_default_authtok comes from LDAP_BIND_PASSWORD. Characters that carry
# special meaning ($, \, ` # and newlines) can break parsing; escape or rotate
# the bind password accordingly.
#
# This script enables PAM mkhomedir, appends pam_exec(common-session) to run
# /opt/hackstack/bin/sssd-local-groups.sh after pam_sss, and runs "systemctl enable --now sssd"
# at the end; plan a reboot afterward so NSS/PAM/session stacks pick up everything cleanly.
#
# Example (run as root, or sudo with env forwarded):
#   sudo env LDAP_BIND_PASSWORD='secret' LDAP_TLS_CACERT=/etc/ssl/certs/your-ca.pem \\
#       ./bin/debian-ldap-login.sh

set -eu

if command -v id >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
	printf '%s requires root; rerun with sudo\n' "$0" >&2
	exit 1
fi

: "${LDAP_BIND_PASSWORD:?LDAP_BIND_PASSWORD must be set (bind DN password for cn=sssd-bind)}"

LDAP_TLS_CACERT="${LDAP_TLS_CACERT:-/etc/ssl/certs/your-ca.pem}"

if [ ! -f "$LDAP_TLS_CACERT" ]; then
	printf 'warning: CA cert path %s does not exist yet - ldaps will fail until installed\n' \
		"$LDAP_TLS_CACERT" >&2
fi

need_restart=0

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

if ! apt-get install -qq -y sssd sssd-ldap libpam-sss libnss-sss oddjob-mkhomedir; then
	printf 'apt-get install failed\n' >&2
	exit 1
fi

# Non-interactively apply bundled pam-config snippets (pam_sss/libnss-sss/etc.) when Debian supports it.
if command -v pam-auth-update >/dev/null 2>&1; then
	pam-auth-update --package 2>/dev/null || true
fi

sssd_tmp="$(mktemp)"
cleanup() {
	rm -f "$sssd_tmp"
}
trap cleanup EXIT

umask 077
cat >"$sssd_tmp" <<CONF
[sssd]
config_file_version = 2
services = nss, pam
domains = pdxhackerspace

[domain/pdxhackerspace]
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap
ldap_uri = ldaps://authentik-ldap:636
ldap_search_base = dc=ldap,dc=pdxhackerspace,dc=org
ldap_default_bind_dn = cn=sssd-bind,ou=users,dc=ldap,dc=pdxhackerspace,dc=org
ldap_default_authtok = ${LDAP_BIND_PASSWORD}
ldap_user_object_class = user
ldap_group_object_class = group
ldap_tls_reqcert = demand
ldap_tls_cacert = ${LDAP_TLS_CACERT}

cache_credentials = true
entry_cache_timeout = 600
offline_credentials_expiration = 0   # 0 = never expire offline creds

CONF

umask 022

mkdir -p /etc/sssd
target=/etc/sssd/sssd.conf
if cmp -s "$sssd_tmp" "$target" 2>/dev/null; then
	printf '%s already matches desired contents (skipping write)\n' "$target"
else
	install -o root -g root -m 0600 "$sssd_tmp" "$target"
	printf 'wrote %s (mode 0600, root:root)\n' "$target"
	need_restart=1
fi

if command -v sssctl >/dev/null 2>&1; then
	sssctl config-check >/dev/null 2>&1 || printf 'warning: sssctl config-check reported issues (see journalctl -u sssd)\n' >&2
elif command -v sssd >/dev/null 2>&1; then
	sssd -t -c "$target" >/dev/null 2>&1 || printf 'warning: sssd -t rejected %s\n' "$target" >&2
fi

if systemctl list-unit-files oddjobd.service >/dev/null 2>&1; then
	systemctl enable oddjobd.service >/dev/null 2>&1 || true
	systemctl start oddjobd.service >/dev/null 2>&1 || true
fi

if [ "$need_restart" -eq 1 ]; then
	systemctl restart sssd.service
	printf 'SSSD restarted\n'
elif systemctl is-active --quiet sssd.service 2>/dev/null; then
	printf '%s unchanged; left SSSD running\n' "$target"
fi

if command -v pam-auth-update >/dev/null 2>&1; then
	pam-auth-update --enable mkhomedir
fi

# Resolve LDAP users into local supplementary groups via pam_exec (see bin/sssd-local-groups.sh).
PAM_COMMON_SESSION=/etc/pam.d/common-session
PAM_EXEC_LINE='session optional pam_exec.so seteuid /opt/hackstack/bin/sssd-local-groups.sh'
if [ -f "$PAM_COMMON_SESSION" ]; then
	if grep -Fq '/opt/hackstack/bin/sssd-local-groups.sh' "$PAM_COMMON_SESSION"; then
		printf '%s already has sssd-local-groups pam_exec\n' "$PAM_COMMON_SESSION"
	elif ! grep -q 'pam_sss\.so' "$PAM_COMMON_SESSION"; then
		printf 'warning: no pam_sss.so in %s; skipping pam_exec line\n' \
			"$PAM_COMMON_SESSION" >&2
	else
		if [ ! -x /opt/hackstack/bin/sssd-local-groups.sh ]; then
			printf 'warning: /opt/hackstack/bin/sssd-local-groups.sh missing or not executable; deploy before relying on LDAP local groups\n' >&2
		fi
		pam_tmp="$(mktemp)"
		awk -v newline="$PAM_EXEC_LINE" '
			$0 ~ /pam_sss\.so/ && !inserted {
				print
				print newline
				inserted = 1
				next
			}
			{ print }
		' "$PAM_COMMON_SESSION" >"$pam_tmp"
		if cmp -s "$pam_tmp" "$PAM_COMMON_SESSION"; then
			rm -f "$pam_tmp"
		else
			install -o root -g root -m 0644 "$pam_tmp" "$PAM_COMMON_SESSION"
			printf 'updated %s (pam_exec after pam_sss)\n' "$PAM_COMMON_SESSION"
			rm -f "$pam_tmp"
		fi
	fi
else
	printf 'warning: %s missing; skipping pam_exec line\n' "$PAM_COMMON_SESSION" >&2
fi

systemctl enable --now sssd.service

printf 'Done. Optional checks after reboot: id <ldap-username>; getent passwd <ldap-username>\n'
printf '\nReboot when convenient so nss/pam/session changes fully apply.\n'
