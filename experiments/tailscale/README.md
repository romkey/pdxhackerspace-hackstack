# tailscale (experiment)

A [Tailscale](https://tailscale.com/) node — `tailscaled` plus WireGuard — that registers with the **`experiments/headscale`** control server instead of Tailscale's SaaS. Headscale on its own only coordinates; it is this container that gives the server an address on the tailnet, and that can advertise the space's LAN to remote members as a subnet router.

Everyone's laptop and phone runs the ordinary Tailscale client pointed at the same `--login-server`. This directory is only for the node that runs *on the Hackstack server*.

Nothing here is specific to headscale: point `--login-server` elsewhere and it is a plain Tailscale node.

## What it is for

Pick whichever applies; they combine:

- **A tailnet address for the server**, so members can reach it without exposing anything publicly.
- **A subnet router**, advertising `192.168.x.0/24` so remote members reach printers, the PDU, ESPHome devices and everything else on the space's LAN without each of them running Tailscale.
- **An exit node**, sending a remote member's whole internet connection out through the space.

## Prerequisites

**`nginx-proxy-net`** (from `apps/nginx-proxy-manager`) must exist, and headscale must be running and reachable at its `server_url`.

Create the state directory on the host:

```bash
mkdir -p ../../lib/tailscale
```

The host needs `/dev/net/tun`, which any stock Linux kernel provides.

## Configuration

```bash
cp .env.example .env
```

Set at least:

| Variable | Purpose |
| --- | --- |
| **`TS_AUTHKEY`** | pre-auth key from headscale, used once on first login |
| **`TS_EXTRA_ARGS`** | must contain `--login-server=https://headscale.example.org` |
| **`TS_HOSTNAME`** | the node's name in the tailnet |
| **`TS_ROUTES`** | subnet routes to advertise, if this is a subnet router |

Generate the key on the headscale side (`--user` takes the numeric id from `users list`):

```bash
cd ../headscale
docker compose exec headscale headscale users create hackstack
docker compose exec headscale headscale users list
docker compose exec headscale headscale preauthkeys create --user 1 --expiration 1h
```

`TS_AUTH_ONCE=true` and the state in `../../lib/tailscale` mean the key is used exactly once; after that the node key authenticates and the key in `.env` is dead weight you can clear.

### Kernel vs userspace networking

`.env.example` sets **`TS_USERSPACE=false`**, so tailscaled uses `/dev/net/tun` and the kernel's WireGuard path. Userspace mode (the image's own default) needs no capabilities or TUN device, but it cannot route subnets or act as an exit node, and it is slower — it is only useful for reaching *into* the tailnet from one container.

Kernel mode is why the compose file grants **`NET_ADMIN`** and **`NET_RAW`**: tailscaled writes iptables rules for its interface.

### Bridge vs host networking

The compose file puts the container on `nginx-proxy-net`, which is enough for a tailnet address and, thanks to Tailscale's default SNAT on subnet routes, enough to route the physical LAN as well — traffic leaves via the Docker bridge and the host's normal routing.

Switch to **`network_mode: host`** (commented out in `docker-compose.yml`, and mutually exclusive with the `networks:` block) when you need:

- an **exit node**, which has to see the host's real interfaces
- the tailnet to reach services bound to the host's loopback
- LAN devices to see the real client IP rather than the container's

In host mode the health endpoint binds port 9002 on the host, so make sure nothing else wants it.

## Subnet routes

Advertising a route does nothing until headscale approves it. From `experiments/headscale`:

```bash
docker compose exec headscale headscale nodes list-routes
docker compose exec headscale headscale nodes approve-routes --identifier 1 --routes 192.168.1.0/24
```

`--identifier` is the numeric node id from `nodes list`. Approving replaces the whole approved set rather than adding to it, so pass every route you want active in one comma-separated list; an empty string revokes them all.

For an exit node, add `--advertise-exit-node` to `TS_EXTRA_ARGS` and approve `0.0.0.0/0,::/0`.

Remote nodes also have to opt in with `--accept-routes` (`--exit-node=<name>` for the exit node); advertising and approving alone changes nothing on their end.

## Usage

```bash
docker compose up -d
docker compose down
docker compose logs -f
```

Check what the node thinks is going on:

```bash
docker compose exec tailscale tailscale status
docker compose exec tailscale tailscale netcheck
```

## Healthcheck

`TS_ENABLE_HEALTH_CHECK=true` makes the container serve **`/healthz`** on `TS_LOCAL_ADDR_PORT` (9002 here), returning 200 once the node holds a tailnet address and 503 before that; `docker-compose.yml` probes it with `wget`. Clearing either variable in `.env` leaves the container permanently unhealthy.

`TS_ENABLE_METRICS=true` adds `/metrics` on the same port.

## Backup

**`../../lib/tailscale`** holds the node's private keys and its copy of the netmap. Restoring it brings the same node back; losing it means registering with a fresh pre-auth key and deleting the stale node from headscale.

Nothing in there is a database, so `backrest` picking up `../../lib` is all the backup it needs.
