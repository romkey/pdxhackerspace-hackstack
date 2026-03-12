#!/bin/sh
#
# install-printer.sh
# Install CUPS and configure the s2-receipt printer (Rongta RP326).
#
# Prerequisites:
#   PRINTER_HOST  - network hostname or IP address of the Rongta RP326 device
#   PRINTER_NAME  - CUPS queue name for the printer (e.g. s2-receipt)
#   Rongta driver - must be installed before running this script;
#                   it provides /usr/share/ppd/rongta/Printer80.ppd

PPD=/usr/share/ppd/rongta/Printer80.ppd

# ── Check prerequisites ────────────────────────────────────────────────────────
err=0

if [ -z "$PRINTER_HOST" ]; then
    echo "Error: PRINTER_HOST is not set." >&2
    echo "  Set it to the hostname or IP address of the Rongta RP326 device." >&2
    echo "  Example: PRINTER_HOST=192.168.1.100" >&2
    err=1
fi

if [ -z "$PRINTER_NAME" ]; then
    echo "Error: PRINTER_NAME is not set." >&2
    echo "  Set it to the desired CUPS queue name for the printer." >&2
    echo "  Example: PRINTER_NAME=s2-receipt" >&2
    err=1
fi

if [ "$err" -ne 0 ]; then
    echo "" >&2
    echo "The Rongta RP326 printer driver must also be installed first." >&2
    echo "It should provide: $PPD" >&2
    exit 1
fi

# ── Install packages ───────────────────────────────────────────────────────────
echo "==> Installing CUPS and print filter packages..."
sudo apt-get install -y \
    cups \
    libcupsimage2 \
    cups-filters \
    cups-pdf \
    ghostscript \
    poppler-utils \
    qpdf \
    imagemagick

# ── Check PPD ─────────────────────────────────────────────────────────────────
if [ ! -f "$PPD" ]; then
    echo "Error: Rongta PPD not found at $PPD" >&2
    echo "Install the Rongta RP326 driver package and re-run this script." >&2
    exit 1
fi

# ── Configure CUPS for local network access ───────────────────────────────────
echo "==> Configuring CUPS..."

CUPSD_CONF=/etc/cups/cupsd.conf

# Ensure CUPS listens on all interfaces, not just localhost.
# Explicit grep check makes this safely re-runnable.
if sudo grep -q '^Listen localhost:631$' "$CUPSD_CONF"; then
    sudo sed -i 's/^Listen localhost:631$/Port 631/' "$CUPSD_CONF"
    echo "  Changed Listen localhost:631 -> Port 631"
else
    echo "  Port 631 already set, skipping"
fi

# Add Allow @LOCAL after every "Order allow,deny" line so subnet clients
# can browse and print.  The grep anchors to actual directives (leading
# whitespace, not a comment #) so a commented-out example line won't
# falsely satisfy the check.
if ! sudo grep -q '^[[:space:]]*Allow @LOCAL' "$CUPSD_CONF"; then
    sudo sed -i '/Order allow,deny/a\  Allow @LOCAL' "$CUPSD_CONF"
    echo "  Added Allow @LOCAL to Location blocks"
else
    echo "  Allow @LOCAL already present, skipping"
fi

# Advertise shared printers via DNS-SD so clients can discover them.
# cupsctl is idempotent.
sudo cupsctl --share-printers

sudo systemctl enable --now cups
sudo systemctl restart cups
echo "CUPS configured (listening on subnet, printer sharing enabled)."

# ── Install the printer queue ─────────────────────────────────────────────────
echo "==> Installing printer queue '$PRINTER_NAME' -> $PRINTER_HOST ..."

# Remove any existing queue with the same name so this is idempotent.
sudo lpadmin -x "$PRINTER_NAME" 2>/dev/null || true

# Add the printer.  Port 9100 is the standard raw/JetDirect socket used
# by Rongta and most thermal network printers.
sudo lpadmin \
    -p "$PRINTER_NAME" \
    -E \
    -v "socket://${PRINTER_HOST}:9100" \
    -P "$PPD" \
    -D "Rongta RP326 Receipt Printer" \
    -L "s2"

# Make it the system default.
sudo lpoptions -d "$PRINTER_NAME"

echo "Printer '$PRINTER_NAME' installed and set as default."
echo ""
echo "Test with:  echo 'Test print' | lpr -P $PRINTER_NAME"
echo "Status:     lpstat -p $PRINTER_NAME"
echo "CUPS UI:    http://$(hostname -I | awk '{print $1}'):631"
