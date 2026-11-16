# prometheus (experiment)

[Prometheus](https://prometheus.io/) collects and stores metrics; view them with **`experiments/grafana`**.

## Services

| Service | What it collects |
|---------|------------------|
| `prometheus` | Scrapes everything below and stores it in `../../lib/prometheus` |
| `node-exporter` | Host CPU, memory, disks, filesystems, network |
| `cadvisor` | Per-container CPU, memory, network and disk I/O |
| `nut-exporter` | UPS status from **`apps/upsd`** |
| `snmp-exporter` | Commented out; uncomment once there's network gear to poll |

## Configuration

### Environment Variables

```bash
cp .env.example .env
```

- `PROMETHEUS_RETENTION` - how long to keep metrics (default `90d`)
- `NUT_EXPORTER_*` - where to find upsd. It publishes port 3493 on the host, so the default `host.docker.internal` works without joining any network.

### Configuration Files

```bash
cp config/prometheus.yml.example config/prometheus.yml
mkdir -p config/secrets
```

`prometheus.yml` scrapes the exporters in this stack out of the box. It also has a commented-out job for every Hackstack app with built-in Prometheus support:

- apps: home-assistant, authentik, jellyfin, llama-cpp, vllm, litellm, watchtower
- experiments: forgejo, headscale, matrix (Synapse), qdrant, uptime-kuma, tailscale, copyparty

Most of them need metrics turned on in the app first; the comment above each job says how. Jobs that need a token or password read it from `config/secrets/<name>`, which is git-ignored. Prometheus runs as uid 65534, so those files must be readable by it.

Home Assistant's Prometheus integration also covers MQTT sensors (zigbee2mqtt, ESPHome, Tasmota) that HA already knows about, so there's no separate MQTT exporter.

After editing `prometheus.yml`, reload without restarting:

```bash
docker compose exec prometheus kill -HUP 1
```

### SNMP

Uncomment `snmp-exporter` in `docker-compose.yml` and the `snmp-*` job in `prometheus.yml`, and list the devices to poll. The image ships profiles (`if_mib`, `apcups`, `synology`, and others) and a `public_v2` community. For other community strings or devices, build a custom `snmp.yml` with the [generator](https://github.com/prometheus/snmp_exporter/tree/main/generator) and mount it at `/etc/snmp_exporter/snmp.yml`.

### Data directory

```bash
mkdir -p ../../lib/prometheus
sudo chown 65534:65534 ../../lib/prometheus
```

### Grafana

Grafana joins `prometheus-net`. Add a Prometheus data source with URL `http://prometheus:9090`. The [Node Exporter Full](https://grafana.com/grafana/dashboards/1860) and [cAdvisor](https://grafana.com/grafana/dashboards/19792) dashboards are good starting points.

The Prometheus UI itself can be proxied at `prometheus:9090`. It has no authentication, so put it behind authentik or leave it unproxied.

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
