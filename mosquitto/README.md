# mosquitto MQTT Broker

Mosquitto provides MQTT service.

Configuration file lives in `docker/mosquitto/config/mosquitto.conf`

Password file lives in `lib/mosquitto/mos_passwd`

You may use `docker/mosquitto/bin/mkuser.sh` to add a new user with a strong password to the broker, or run
```
docker compose exec mosquitto mosquitto_passwd
```
and pass the needed options.

`mosquitto_subscribe` and `mosquitto_publish` are also available inside the container and may be run using `docker compose exec`

Our default configuration of mosquitto creates a Docker network called `mosquitto-net`. Any applications which need to use MQTT should be on this network. The broker is also accessible outside the host computer on port 1883.
