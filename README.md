# PDX Hackerspace Docker Hackstack

This repo configures a set of services that PDX Hackerspace uses to provide services for its members and for infrastructure, administration and yes, fun and entertainment.

## Philosophy

1. Keep the underlying system hosting the servers as clean and unpolluted as possible. Whenever possible, install software in a container configured by this repository. The goal is to be able to easily spin up a new instance on a fresh server without having to do extensive configuration of the Linux system running the services.

2. Separate configuration, run time and persistent state, and logs. Store all of them consistently in order to make administration and backups as easy possible. Configuration is managed by this repository, with `.env` files holding configuration.

  To this end, for each service we store:

  configuration - `docker-compose.yml`, `.env` and configuration directories or files in its own directory in `/opt/docker`
  run time and persistent state - `/opt/lib`
  logs - `/opt/logs`
  
3. Isolate services from the Internet, local network and one another whenever reasonable. While we are not going to heroic efforts to secure the services, isolation will help reduce the impact that a misbehaving service might have, and will reduce the likelihood of the service being susceptible to mischief.

  To this end, whenever possible we do not expose container ports. In some cases (like dnsmasq or rsyslog) there's no choice, but whenever it's possible we route
  traffic to the container through nginx-proxy-manager using a unique hostname, rather than directly expose them. This limits the

4. Many Docker Compose projects bundle their own database or other services. We prefer to use a single instance of each flavor of database - this simplifies management and backup and reduces overhead. The potential drawbacks are single point of failure and version skew. Postgresql is a tank and is unlikely to be the point of failure. If it is, it needs to get fixed ASAP. And both Postgresql and Mariadb have good histories with backwards compatability.

## Caveats

While we have tried to minimize dependencies on absolute pathnames, there may be places that we missed.

We've also tried to organize things so that `docker-compose.yml` files don't need to be modified but there may be places where this is unavoidable.

We're running on Debian 12 (bookworm) server with no GUI and as few extra packages installed as possible. This is unlikely to work on macOS or Windows without modification.

## Installation

First, install [Docker Engine](), [Docker CLI]() and [Docker Compose]() on your system.

## Services

### Core Services

These are essential services (like databases and reverse proxies) that other services use. 

#### avahi-mdns

[Avahi mDNS server](https://avahi.org) - implements [RFC 6762 Multicast DNS](https://www.rfc-editor.org/rfc/rfc6762),
which is well supported and used commonly by Apple products. This allows us to use the .local domain
and allows services to advertise their availability.

Not currently in use, unlikely to work correctly, on the TODO list

### backrest

[backrest](https://github.com/garethgeorge/backrest) - web UI to [Restic](https://restic.net) back up software. We use
this to back up files to the NAS.

By default we give backrest sweeping access to the filesystem so that it can not only backup the state of these services, but the configuration and user files of the Debian server we host the services on.

### cloudflare-ddns

[cloudflare-ddns](https://github.com/oznu/docker-cloudflare-ddns) Updates a Cloudflare domain name when our IP address changes. We make a number of services available to members 

### db-backup


### dns-masq

[dns-masq](https://thekelleys.org.uk/gitweb/?p=dnsmasq.git) is a lightweight DNS server and DHCP server. We only use currently only use its DNS functions.

We use dnsmasq to provide name service for the 

### glances

System monitoring

### mariadb

Mariadb (successor to MySQL)

### mdns-repeater

Repeats mDNS traffic between a network interface and a Docker network. Allows containers to use private Docker networking instead of host network mode.

### nginx-proxy-manager



### portainer

### postgresql

Postgresql database

### redis


### upsd

UPS monitor and NUT (Network UPS Tool)

### watchtower

Automatically attempt to update docker containers when new images are released

## Home Assistant-related services

We prefer to run things like Mosquitto and Zigbee2MQTT separately from Home Assistant. This gives us more flexibility
in how we manage those services, which may also be u

### ESPHome

### Home Assistant

### Matter

### Mosquitto

### Mosquitto Management Center

### MQTT Explorer

### OpenWakeWord

### Piper

### rtlamr2mqtt

### Whisper

### Zigbee2MQTT

## AI/LLM

