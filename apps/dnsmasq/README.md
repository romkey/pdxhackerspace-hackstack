# dnsmasq

Lightweight DNS for the **`*.ctrlh`** zone (hostnames under `hosts.d` / `autohosts.d`). DHCP is not used here—the router handles that.

## Configuration

### Configuration Files

Configuration files are stored in the `config/` directory.

## LAN macvlan (optional)

By default this app uses bridge and/or host networking in `docker-compose.yml`. For a **dedicated LAN IPv4 and MAC** on the shared **`lan_macvlan`** network, set in **`.env`** (see **`.env.example`** and [docs/macvlan.md](../../docs/macvlan.md)):

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.macvlan.yml
```

Assign a unique **`IPV4_ADDRESS`** and **`LAN_MAC_ADDRESS`** per app. Run **`../../bin/create-macvlan.sh`** from the repo root once (see [docs/macvlan.md](../../docs/macvlan.md)).


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
