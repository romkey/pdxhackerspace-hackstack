# laser-cutterd (experiment)

[laser-cutterd](https://github.com/romkey/laser-cutterd) polls a Ruida laser controller over UDP and publishes its status, position and lifetime counters to MQTT, with Home Assistant discovery so the laser shows up as a device on its own.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

| Variable | Notes |
|----------|-------|
| `RUIDA_HOST` | The controller's IP address (required) |
| `RUIDA_MAGIC` | `0x88` for RDC644x/654x/633x/320 boards, `0x11` for 634XG |
| `MQTT_HOST` / `MQTT_USERNAME` / `MQTT_PASSWORD` | `apps/mosquitto` |
| `DEVICE_ID` / `DEVICE_NAME` / `DEVICE_MODEL` | How the laser appears in Home Assistant |
| `PORT` | HTTP port for `/healthz` and `/status` on the host (default here `8010`, since vllm uses `8000`) |

See [docs/configuration.md](https://github.com/romkey/laser-cutterd/blob/main/docs/configuration.md) for everything else.

### Host networking

This service uses `network_mode: host`. The controller sends its replies to UDP port 40200 on this host, which Docker's NAT can't be relied on to deliver. As a result:

- MQTT is reached through the port mosquitto publishes on the host, so `MQTT_HOST=127.0.0.1`.
- Only one program on this host can use UDP 40200, so LightBurn or RDWorks can't talk to the laser from this machine while it runs.
- The HTTP API binds on the host. `HOST=127.0.0.1` keeps it private; set `0.0.0.0` to reach `/status` from the LAN.

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
