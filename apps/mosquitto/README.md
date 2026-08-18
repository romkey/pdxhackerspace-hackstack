# mosquitto MQTT Broker

Mosquitto provides MQTT service for Hackstack applications and clients.

Configuration file lives in `config/mosquitto.conf` (copy from `mosquitto.conf.example`).

Password file lives in `config/mos_passwd` (see `.gitignore`; create with `bin/mkuser.sh`).

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure healthcheck credentials when anonymous access is disabled:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `MOSQUITTO_HEALTHCHECK_USERNAME` | MQTT user for container healthcheck (needs read access to `$SYS/#`) |
| `MOSQUITTO_HEALTHCHECK_PASSWORD` | Password for healthcheck user |

### Broker configuration

Edit `config/mosquitto.conf` for listeners, ACLs, and authentication. Use `bin/mkuser.sh` to manage users in `config/mos_passwd`.

## Healthcheck (authenticated brokers)

The container healthcheck runs `mosquitto_sub` to `$SYS/broker/uptime`. When **`allow_anonymous false`** (or you use a `password_file` without anonymous access), set `MOSQUITTO_HEALTHCHECK_USERNAME` and `MOSQUITTO_HEALTHCHECK_PASSWORD` in `.env`.

Use a dedicated low-privilege MQTT user that exists in `mos_passwd`. If you use **`acl_file`**, that user must be allowed to **subscribe/read** topics under **`$SYS/#`** (or at least `$SYS/broker/uptime`).

Avoid shell metacharacters in the healthcheck password if possible (`$`, `` ` ``, `"`, `\`).

You may use `bin/mkuser.sh` to add a new user with a strong password to the broker, or run:

```bash
docker compose exec mosquitto mosquitto_passwd
```

`mosquitto_sub` and `mosquitto_pub` are also available inside the container via `docker compose exec`.

Our default configuration creates Docker network `mosquitto-net`. Applications that need MQTT should join that network. The broker is also accessible outside the host on port 1883.

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
docker compose logs -f mosquitto
```
