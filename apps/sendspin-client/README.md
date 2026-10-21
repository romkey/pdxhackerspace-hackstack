# sendspin-client

Sendspin client for streaming audio to Music Assistant.

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
# Edit .env with your settings
```

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
