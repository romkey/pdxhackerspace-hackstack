# App `docker-compose` healthchecks

This document complements the healthchecks defined under `apps/*/docker-compose.yml`.

## Services that already had healthchecks (unchanged here)

- **authentik**, **cups**, **dozzle**, **dozzle-agent**, **event-manager**, **glitchtip**, **invidious**, **mariadb**, **member-manager**, **nginx-proxy-manager**, **planka**, **sentry**

## Healthchecks added (summary)

| App | Check type | Notes |
|-----|------------|--------|
| **postgresql** | `pg_isready` | Cluster accepting connections. |
| **mosquitto** | `mosquitto_sub` on `$SYS/broker/uptime` with **`MOSQUITTO_HEALTHCHECK_USERNAME` / `MOSQUITTO_HEALTHCHECK_PASSWORD`** from `.env` | Required when anonymous access is disabled; user must exist in `mos_passwd` and (if using ACLs) be allowed `$SYS/#`. |
| **vaultwarden** | HTTP `/alive` | |
| **home-assistant** | HTTP `:8123` | Long `start_period` for first boot. |
| **jellyfin** | HTTP `:8096/health` | |
| **ollama** | HTTP `:11434` | Also sets `hostname: ollama` (was missing). |
| **openwebui** | HTTP `:8080` | In-container port (not host `3000`). |
| **esphome** | HTTP `:6052` | |
| **adminer** | HTTP `:8080` | |
| **cyberchef** | HTTP `:80` | |
| **matomo** | `matomo-nginx` only: HTTP `:80` | PHP-FPM has no trivial HTTP probe in this stack. |
| **calibre-web** | HTTP `:8083` | LinuxServer default. |
| **zigbee2mqtt** | HTTP `:8080` frontend | Long `start_period` for USB/coordinator init. |
| **mopidy** | HTTP `:6680` | Web client; MPD `:6600` not probed. |
| **wiki** (Wiki.js) | HTTP `:3000` | |
| **partdb** | HTTP `:80` | |
| **weather** | `wget --spider` nginx `:80` | |
| **llama-cpp** | HTTP `/health` or `/v1/models` | Matches common `llama-server` layouts. |
| **statping** | HTTP `:8080` | |
| **peanut** | Image default: `node healthcheck.mjs` → `/api/ping` on `WEB_PORT` | Do not override with `wget`; the Node image has no wget. |
| **geowiki** | HTTP `:3000` | Uses `PORT` from `.env` (default 3000). |
| **access-control-webhook** | `wget --spider` `:9000` | |
| **netbootxyz** | `wget --spider` nginx `:80` | |
| **glances** | `wget --spider` `:61208` | Assumes `-w` / web UI in `.env` (`GLANCES_OPT=-w`). |
| **backrest** | HTTP `:9898` | |
| **z-wavejs** (UI) | HTTP `:8091` | |
| **matter** | TCP `:5580` | Bash `/dev/tcp`; needs `bash` in image. |
| **piper** | TCP `:10200` | Default Wyoming port; change if you override the listener. |
| **whisper** | TCP `:10300` | Same as above; long `start_period` for model load. |
| **postfix** | TCP `:587` | Submission port listening. |
| **music-assistant** | `wget -qO-` GET `:8095` | `network_mode: host`. (`wget --spider` uses **HEAD** and MA logs it as unhandled.) |
| **dnsmasq** | `pidof dnsmasq` | |
| **rsyslog** | `pidof rsyslogd` | |
| **snapserver** | TCP `:1704` | Snapcast stream port; needs `bash`. |
| **snapclient** | `ps \| grep` process | Avoids `pgrep` on minimal images. |
| **caddy-home-assistant-liar** | `wget --spider` admin `:2019/config/` | **Fails if admin API is disabled** in Caddy config. |
| **authentik-ak-outpost** | TCP `:9000` | Default outpost listen port. |
| **mosquitto-management-center** | HTTP `:8088` | Cedalo default UI port. |
| **shairport-metadata-display** | `wget --spider` `:8080` | |
| **autogenerate-hosts** | `ps \| grep` Ruby watcher | |
| **db-backup** | `ps \| grep` `backup.rb` | Long interval / `start_period` (first backup cycle can be slow). |
| **upsd** | TCP `:3493` | NUT `upsd` default. |
| **shairport-sync** | `pidof shairport-sync` | |
| **mdns-repeater** | `ps \| grep`; **`hostname` added** | Matches compose conventions. |
| **mqtt-explorer** | `wget --spider` `:4000` | Common for this image; change if your build uses another port. |

## Intentionally no healthcheck (or use with caution)

| App | Reason |
|-----|--------|
| **watchtower** | No long-lived HTTP/TCP API suitable for probes. |
| **cloudflare-ddns** | Periodic script; no listen socket. |
| **sensors2mqtt** | MQTT publisher only; no standard health port. |
| **airconnect** | Host networking + AirConnect process; binary/flags vary. |
| **bfg-repo-cleaner** | One-shot / interactive container (`restart: "no"`). |
| **auto_planka** | Automation against DB; not an HTTP server. |

If your deployment differs (custom ports, auth on Mosquitto, disabled Caddy admin, etc.), adjust or remove the healthcheck in that app’s `docker-compose.yml`.
