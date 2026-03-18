# cups

Containerised CUPS print server using the
[LinuxServer CUPS image](https://docs.linuxserver.io/images/docker-cups/),
which ships with a comprehensive set of print filters and supporting programs:

| Package | Purpose |
|---|---|
| `cups` | Core print server and IPP listener |
| `cups-filters` | PDF, PostScript, raster, and text filter chain |
| `ghostscript` | PS/PDF rendering |
| `poppler-utils` | PDF inspection and conversion |
| `qpdf` | PDF linearisation and repair |
| `imagemagick` | Image format conversion (PNG, JPEG, TIFF, …) |
| `foomatic-db` + `foomatic-db-engine` | Generic printer driver database |
| `printer-driver-gutenprint` | High-quality open-source raster drivers |
| `hplip` | HP printer drivers |
| `libcupsimage2t64` | CUPS raster image library |

## Networks

| Network alias | Actual network | Purpose |
|---|---|---|
| `cups` | `cups-net` | Other containers join this to submit print jobs |
| `proxy` | `nginx-proxy-net` | Reverse proxy access to the CUPS web UI |

## Volumes

| Mount | Purpose |
|---|---|
| `../../lib/cups` → `/config` | All CUPS state: config, spool, logs, per-queue PPDs |
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
cp .env.example .env
# Edit .env if you need non-default PUID/PGID or TZ
docker compose up -d
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
