#!/bin/bash
#
# mksmtp.sh — create a dedicated SMTP auth account for an application.
#
# Usage: mksmtp.sh <app-name>
#
# Creates a Cyrus SASL account USERNAME@DOMAIN inside the running postfix
# container and prints all parameters needed to configure the app.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POSTFIX_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Argument check ─────────────────────────────────────────────────────────────
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <app-name>" >&2
    exit 1
fi

APP="$1"

# ── Dependency check ───────────────────────────────────────────────────────────
if ! command -v pwgen >/dev/null 2>&1; then
    echo "pwgen not found — needed to generate a password." >&2
    echo "Install with: apt install pwgen" >&2
    exit 1
fi

# ── Read postfix config ────────────────────────────────────────────────────────
ENV_FILE="$POSTFIX_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found." >&2
    echo "Copy .env.example to .env and configure postfix before running this script." >&2
    exit 1
fi

# Source only the SASL domain variable to avoid polluting the environment.
SASL_DOMAIN="$(grep '^POSTFIX_smtpd_sasl_local_domain=' "$ENV_FILE" | cut -d= -f2- | tr -d '[:space:]')"

if [ -z "$SASL_DOMAIN" ]; then
    echo "Error: POSTFIX_smtpd_sasl_local_domain is not set in $ENV_FILE." >&2
    exit 1
fi

SMTP_USER="${APP}@${SASL_DOMAIN}"
SMTP_PASS="$(pwgen 24 1)"
SMTP_HOST="postfix"
SMTP_PORT="587"
SMTP_URL="smtp://${APP}%40${SASL_DOMAIN}:${SMTP_PASS}@${SMTP_HOST}:${SMTP_PORT}"

# ── Check postfix container is running ────────────────────────────────────────
echo "Checking postfix container..."
if ! docker compose -f "$POSTFIX_DIR/docker-compose.yml" ps postfix 2>/dev/null | grep -q "Up"; then
    echo "Error: postfix container is not running." >&2
    echo "Start it with: docker compose -f $POSTFIX_DIR/docker-compose.yml up -d postfix" >&2
    exit 1
fi
echo "  ✓ postfix is running"
echo

# ── Create the SASL account ────────────────────────────────────────────────────
echo "Creating SMTP account: ${SMTP_USER}"
if echo "$SMTP_PASS" | docker compose -f "$POSTFIX_DIR/docker-compose.yml" \
        exec -T postfix saslpasswd2 -c -u "$SASL_DOMAIN" "$APP"; then
    echo "  ✓ Account created"
else
    echo "  ✗ Failed to create account" >&2
    exit 1
fi

# ── Output credentials ─────────────────────────────────────────────────────────
echo
echo "================================================================"
echo "SMTP credentials for: ${APP}"
echo "================================================================"
echo "  Host:     ${SMTP_HOST}"
echo "  Port:     ${SMTP_PORT}"
echo "  Username: ${SMTP_USER}"
echo "  Password: ${SMTP_PASS}"
echo "  URL:      ${SMTP_URL}"
echo "================================================================"
echo
echo "Add to ${APP}/.env:"
echo "  SMTP_HOST=${SMTP_HOST}"
echo "  SMTP_PORT=${SMTP_PORT}"
echo "  SMTP_USER=${SMTP_USER}"
echo "  SMTP_PASSWORD=${SMTP_PASS}"
echo "  EMAIL_URL=${SMTP_URL}"
echo
echo "Note: the URL uses %40 for the @ in the username."
