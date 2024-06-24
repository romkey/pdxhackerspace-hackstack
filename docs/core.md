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

### BFG Repo Cleaner

### cloudflare-ddns

[cloudflare-ddns](https://github.com/oznu/docker-cloudflare-ddns) Updates a Cloudflare domain name when our IP address changes. We make a number of services available to members 

### db-backup


### dns-masq

[dns-masq](https://thekelleys.org.uk/gitweb/?p=dnsmasq.git) is a lightweight DNS server and DHCP server. We only use currently only use its DNS functions.

We use dnsmasq to provide name service for the various servers that we run.

dnsmasq can be difficult to configure properly. This [cheatsheet](https://etherarp.net/dnsmasq/index.html) may help.

### glances

Glances provides system monitoring

### mariadb

Mariadb (successor to MySQL)

### mdns-repeater

Repeats mDNS traffic between a network interface and a Docker network. Allows containers to use private Docker networking instead of host network mode.

### Nginx Proxy Manager

Nginx Proxy Manager is a simple web-based UI that manages reverse proxies using Nginx. It can automatically 


### portainer

### postgresql

Postgresql database

### redis


### upsd

UPS monitor and NUT (Network UPS Tool)

### watchtower

Automatically attempt to update docker containers when new images are released
