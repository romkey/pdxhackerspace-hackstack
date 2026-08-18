# dozzle

[Dozzle](https://dozzle.dev/) serves Docker container logs through a web UI.

## Configuration

Copy `.env.example` to `.env` and configure authentication or remote agents as needed:

```bash
cp .env.example .env
```

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

## Agent

Run the Dozzle agent on satellite hosts (see `apps/dozzle-agent/`):

```bash
docker compose up agent -d
```

Dozzle Agent will not report RAM usage on Raspberry Pis running Raspberry Pi OS without this change:

Edit `/boot/firmware/cmdline.txt` and add this to the **end** of the command line (after a space, not on a new line):

```
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```
