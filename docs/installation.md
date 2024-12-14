## Installation

Hackstack is designed to require minimal additional software installed
on a stock Linux server. Whenever possible dependencies are isolated
within Docker containers. PDX Hackerspace runs Hackstack on a Debian
installation. Unless you absolutely require a GUI we recommend saving
the resources that it would take and just running a "server"-stye
system with no graphic user interface.

First, install [Docker CLI](https://docs.docker.com/engine/install/)
and if needed Docker Compose on your system.

Then make sure `git` is installed. On Debian-style systems you can do
this with:
```
sudo apt update
sudo apt install git
```

Then clone the Hackstack repo, preferably into `/opt/docker`:
```
git clone https://github.com/romkey/pdxhackerspace-hackstack
```

At that point you can begin spinning up services. Start with
foundational services like `dnsmasq`, `postgresql` and `mariadb` if
you need them. For each service you'll want to edit its `.env` file if
there is one and then bring up its Docker container. For instance, for
`calibre-web` you would:
```
cd /opt/docker/calibre
cp .env.example .env
vi .env
docker compose up -d
```
