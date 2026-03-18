# cups

Containerised CUPS print server using [`olbat/cupsd`](https://hub.docker.com/r/olbat/cupsd)
— 1M+ pulls, updated weekly, Debian-based, amd64 + arm64.

Included packages (from Debian):

| Package | Purpose |
|---|---|
| `cups` + `cups-client` + `cups-filters` | Core print server, IPP, full filter pipeline |
| `printer-driver-all` | Debian meta-package: gutenprint, splix, foo2zjs, dymo, and dozens more |
| `openprinting-ppds` | OpenPrinting PPD collection |
| `hpijs-ppds` + `hp-ppd` | HP printer PPDs |
| `foomatic-db` | Generic printer driver database |
| `printer-driver-cups-pdf` | Virtual PDF printer |
| `smbclient` | Windows/SMB shared printer support |

Default admin credentials: **`print` / `print`**

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
