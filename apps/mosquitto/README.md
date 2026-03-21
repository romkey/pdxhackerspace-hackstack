# mosquitto MQTT Broker

Mosquitto provides MQTT service.

Configuration file lives in `apps/mosquitto/config/mosquitto.conf` (copy from `mosquitto.conf.example`).

Password file lives in `apps/mosquitto/config/mos_passwd` (see `.gitignore`; create with `bin/mkuser.sh`).

## Healthcheck (authenticated brokers)

The container healthcheck runs `mosquitto_sub` to `$SYS/broker/uptime`. When **`allow_anonymous false`** (or you use a `password_file` without anonymous access), set in **`.env`**:

- `MOSQUITTO_HEALTHCHECK_USERNAME`
- `MOSQUITTO_HEALTHCHECK_PASSWORD`

Use a dedicated low-privilege MQTT user that exists in `mos_passwd`. If you use **`acl_file`**, that user must be allowed to **subscribe/read** topics under **`$SYS/#`** (or at least `$SYS/broker/uptime`).

Avoid shell metacharacters in the healthcheck password if possible (`$`, `` ` ``, `"`, `\`).

You may use `apps/mosquitto/bin/mkuser.sh` to add a new user with a strong password to the broker, or run
```
docker compose exec mosquitto mosquitto_passwd
```
and pass the needed options.

`mosquitto_subscribe` and `mosquitto_publish` are also available inside the container and may be run using `docker compose exec`

Our default configuration of mosquitto creates a Docker network called `mosquitto-net`. Any applications which need to use MQTT should be on this network. The broker is also accessible outside the host computer on port 1883.
