# nextcloud (experiment)

[Nextcloud](https://nextcloud.com/) file sync and collaboration, using the official Docker image with the shared PostgreSQL service (`postgres-net`).

## Configuration

Copy `.env.example` to `.env` and set database credentials, admin user, trusted domains, and optional `IMAGE_VERSION`.

Configuration reference: [Nextcloud Docker environment variables](https://github.com/nextcloud/docker#auto-configuration-via-environment-variables).

## Networks

- **`nginx-proxy-net`** — reverse proxy to the web container (port **80** inside the container unless you change it)
- **`postgres-net`** — PostgreSQL as `postgresql:5432`

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

Persistent data: **`../../lib/nextcloud`**.
