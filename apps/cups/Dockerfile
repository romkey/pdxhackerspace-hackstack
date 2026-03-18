FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core print server
    cups \
    cups-client \
    # Filter pipeline: PDF, PostScript, raster, text
    cups-filters \
    cups-browsed \
    # PostScript / PDF rendering
    ghostscript \
    # PDF utilities
    poppler-utils \
    qpdf \
    # Image conversion (TIFF, PNG, JPEG, BMP, …)
    imagemagick \
    # CUPS raster image library
    libcupsimage2t64 \
    # Generic printer driver database + filter
    foomatic-db \
    foomatic-db-engine \
    foomatic-db-compressed-ppds \
    # High-quality open-source raster drivers (Epson, Canon, etc.)
    printer-driver-gutenprint \
    # HP printers
    hplip \
    # Brother / generic PCL
    printer-driver-foo2zjs \
    # Dymo label printers
    printer-driver-dymo \
    # PostScript-capable printers (pxljr, etc.)
    printer-driver-pxljr \
    # m2300w / m3300mfp
    printer-driver-m2300w \
    # SpliX (Samsung/Xerox SPL-II raster)
    printer-driver-splix \
    # Healthcheck / debug
    curl \
    && rm -rf /var/lib/apt/lists/*

# Directories CUPS expects at runtime
RUN mkdir -p \
    /var/spool/cups/tmp \
    /var/log/cups \
    /run/cups \
    /usr/share/cups/model/custom

# Run CUPS in the foreground (-f) so Docker captures stdout/stderr
EXPOSE 631

CMD ["/usr/sbin/cupsd", "-f"]
