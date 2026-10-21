# Macvlan (optional LAN attachment)

Some services must look like **physical hosts on the LAN** (mDNS, Matter, ESPHome OTA, AirPlay, DNS, PXE). Hackstack keeps them on **bridge networks by default** in `docker-compose.yml`. To add a **dedicated LAN IPv4 and MAC**, use **`docker-compose.macvlan.yml`** and enable it from **`.env`**:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml
```

## Shared network

All macvlan apps attach to one Docker network (default name **`lan_macvlan`**). Create it once from the repo root:

```bash
./bin/create-macvlan.sh
```

The script finds host interfaces with **global IPv4** addresses (skipping `docker0`, `br-*`, `veth*`, etc.). If **exactly one** candidate exists, it asks you to confirm; if **several** exist, it **lists them and makes you choose** (marks the default route). It derives **subnet** and **gateway** from `ip` routing, then runs `docker network create`.

Options: `-y` skip prompts, `-f` replace an existing network, `-n` custom network name. Override any value with **`MACVLAN_*`** env vars.

Manual equivalent:

```bash
docker network create -d macvlan \
  -o "parent=${MACVLAN_PARENT}" \
  --subnet="${MACVLAN_SUBNET}" \
  --gateway="${MACVLAN_GATEWAY}" \
  --ip-range="${MACVLAN_IP_RANGE}" \
  "${LAN_NET_NAME:-lan_macvlan}"
```

All macvlan overlays (including **home-assistant**) attach to that network as **`external: true`**.

## Per-app settings (`.env`)

| Variable | Purpose |
|----------|---------|
| `MACVLAN_PARENT` | Host NIC (e.g. `enp45s0`) |
| `MACVLAN_SUBNET` / `MACVLAN_GATEWAY` / `MACVLAN_IP_RANGE` | LAN IPAM (static IPs you assign in `.env`) |
| `LAN_NET_NAME` | Docker network name (default `lan_macvlan`) |
| `IPV4_ADDRESS` | This container’s LAN address |
| `LAN_MAC_ADDRESS` | Locally administered MAC (stable across recreates) |

Use a **registry** (spreadsheet or internal doc) so each app has a unique IP/MAC pair. Example prefix: `02:48:53:<site>:<app-id>:<instance>`.

## Reachability with Home Assistant on macvlan

HA should stay on **`hass-net`**, **`mqtt-net`**, and **`nginx-proxy-net`** as well as **`lan`**. Integrations that use Docker names (piper, z-wave, MQTT) keep working.

- **`network_mode: host`** services (Music Assistant, dnsmasq, AirPlay helpers): HA must use the **host’s LAN IP**, not `127.0.0.1`.
- **Macvlan services**: use each service’s **`IPV4_ADDRESS`** from ESP devices, phones, and TVs.

## Host vs macvlan overlay

Services that default to **`network_mode: host`** can switch to macvlan via the overlay (Compose **`!reset`** on `network_mode`). Test discovery (AirPlay, MA) after switching; keep host mode if macvlan misbehaves on your NIC/driver.

## Gotchas

- **Parent host** cannot reach macvlan children on the same parent without a **macvlan shim** on the host — use bridge networks for HA↔container traffic.
- **No router DHCP** for container MACs unless you run a client inside the container; we use **static** `IPV4_ADDRESS`.
- **Duplicate IP/MAC** on the LAN breaks everything — maintain the registry.
- **Wi‑Fi** parent interfaces often fail for macvlan; use **wired** `MACVLAN_PARENT`.

See [Contributing](contributing.md) and per-app READMEs.
