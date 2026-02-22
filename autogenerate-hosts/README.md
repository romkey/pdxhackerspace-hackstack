# autogenerate-hosts

Watches the [nginx-proxy-manager](../nginx-proxy-manager/) SQLite database and
automatically generates a hosts file for dnsmasq based on the configured proxy
hosts. This keeps local DNS in sync with the reverse proxy configuration
without manual intervention.

Image source: [romkey/pdxhackstack-autogenerate-hosts](https://github.com/romkey/pdxhackstack-autogenerate-hosts)

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

| Variable | Description | Example |
|----------|-------------|---------|
| `TARGET_IP` | IP address to use for all generated host entries | `192.168.13.2` |
| `DOMAIN_NAME` | Local domain suffix for generated hostnames | `ctrlh` |
| `DNSMASQ_PATH` | Path inside the container to write the generated hosts file | `/dest/npm-hosts` |
| `HOSTSFILE_PATH` | Host path that maps to `/dest` inside the container | `/opt/lib/dnsmasq/autohosts.d` |
| `DB_PATH` | Host path to the nginx-proxy-manager SQLite database | `/opt/docker/nginx-proxy-manager/data/database.sqlite` |
| `TZ` | Timezone | `America/Los_Angeles` |
| `IMAGE_VERSION` | Docker image tag (optional, defaults to `latest`) |  |

`DB_PATH` is bind-mounted into the container at the same path, so the value is
used for both sides of the volume mount.

## Usage

### Starting the service

```bash
docker compose up -d
```

### Stopping the service

```bash
docker compose down
```

### Viewing logs

```bash
docker compose logs -f
```
