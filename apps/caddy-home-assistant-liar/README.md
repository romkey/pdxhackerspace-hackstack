# caddy-home-assistant-liar

A Caddy reverse proxy that spoofs `X-Forwarded-For` and `X-Real-IP` headers to
make Home Assistant believe incoming requests originate from a trusted local IP
address. This bypasses Home Assistant's IP-based authentication check when
requests arrive via nginx-proxy-manager from a non-RFC1918 source.

## How it works

nginx-proxy-manager → **caddy-home-assistant-liar** → home-assistant

Caddy rewrites the forwarded IP headers to `192.168.0.0` before passing
requests upstream to `home-assistant:8123`. Home Assistant sees a local IP
and grants access without requiring authentication.

## Configuration

### Caddyfile

Copy the default config and edit as needed:

```bash
cp config/Caddyfile.default config/Caddyfile
```

Key settings in `config/Caddyfile`:

| Setting | Description |
|---------|-------------|
| `trusted_proxies static <IP>` | IP of the nginx-proxy-manager container on the caddy network — check with `docker inspect` if it changes |
| `X-Forwarded-For` / `X-Real-IP` | Spoofed local IP sent to Home Assistant |
| `reverse_proxy home-assistant:8123` | Upstream Home Assistant container (resolved via hass-net) |

### Environment Variables

No required environment variables. Optionally set `IMAGE_VERSION` in `.env`
to pin the Caddy image tag.

## Network dependencies

| Network | Provided by | Purpose |
|---------|-------------|---------|
| `nginx-proxy-net` | nginx-proxy-manager | Receives inbound requests from the reverse proxy |
| `hass-net` | home-assistant | Reaches `home-assistant:8123` by container name |
| `caddy-home-assistant-liar-net` | this service | Internal network created by this service |

## Usage

### Starting the service

```bash
# Configure Caddyfile first
cp config/Caddyfile.default config/Caddyfile
# Edit config/Caddyfile if needed, then:
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

### Reloading Caddy config without restart

```bash
docker compose exec caddy-home-assistant-liar caddy reload --config /etc/caddy/Caddyfile
```
