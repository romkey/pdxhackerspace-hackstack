# cups

Containerised CUPS print server built from a Debian Bookworm base with a
comprehensive set of print filters and drivers installed:

| Package | Purpose |
|---|---|
| `cups` + `cups-client` | Core print server and IPP listener |
| `cups-filters` + `cups-browsed` | PDF, PostScript, raster, and text filter chain |
| `ghostscript` | PS/PDF rendering |
| `poppler-utils` | PDF inspection and conversion |
| `qpdf` | PDF linearisation and repair |
| `imagemagick` | Image format conversion (PNG, JPEG, TIFF, …) |
| `libcupsimage2t64` | CUPS raster image library |
| `foomatic-db` + `foomatic-db-engine` + `foomatic-db-compressed-ppds` | Generic printer driver database |
| `printer-driver-gutenprint` | High-quality open-source raster drivers (Epson, Canon, etc.) |
| `hplip` | HP printer drivers |
| `printer-driver-foo2zjs` | Brother / generic PCL drivers |
| `printer-driver-dymo` | Dymo label printers |
| `printer-driver-splix` | Samsung / Xerox SPL-II raster |
| `printer-driver-pxljr` | PostScript-capable PCL drivers |

## Networks

| Network alias | Actual network | Purpose |
|---|---|---|
| `cups` | `cups-net` | Other containers join this to submit print jobs |
| `proxy` | `nginx-proxy-net` | Reverse proxy access to the CUPS web UI |

## Volumes

| Mount | Purpose |
|---|---|
| `../../lib/cups` → `/config` | All CUPS state: spool, logs, per-queue PPDs |
| `./config/cupsd.conf` → `/etc/cups/cupsd.conf` (read-only) | Scheduler config; pre-configured to accept connections from `@LOCAL` (all Docker networks and LAN hosts) |
| `./ppds` → `/usr/share/cups/model/custom` (read-only) | Custom PPD files; any PPD placed here appears as an available driver in the CUPS add-printer wizard |

## Adding custom PPDs

Drop `.ppd` files into the `ppds/` directory next to this file.  They are
mounted read-only into CUPS's model directory and appear automatically under
**Administration → Add Printer → Choose Driver** the next time you open the
wizard (no restart required).

Example — adding the Rongta RP326 driver:

```sh
cp /path/to/Printer80.ppd apps/cups/ppds/
```

## First-time setup

```sh
cp config/cupsd.conf.default config/cupsd.conf
# Edit config/cupsd.conf if you need to restrict or expand access

docker compose up -d --build
```

The CUPS web UI is available at `http://cups:631` from other containers on
`cups-net`, or via nginx-proxy-manager if you set up a proxy host pointing
to `cups:631`.

To allow other containers to print without credentials, open the CUPS web UI
and under **Administration → Server** enable:

- Allow printing from the Internet
- Allow remote administration

## Adding a printer from another container

Any container that needs to print should join `cups-net`:

```yaml
networks:
  cups:
    external: true
    name: cups-net
```

Then configure the app's printer URL as `ipp://cups:631/printers/<queue-name>`.

## Stopping safely

```sh
docker compose down
```
