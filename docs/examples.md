# Examples

On our primary server we're running the full stack. These services aren't things that end users would generally interact with, and gives us a sturdy foundation to run other applications on.

- **nginx-proxy-manager** — reverse proxies for local and public services. Each service has a hostname or domain name; Nginx Proxy Manager maps that name to the service. Local names end in `.ctrlh`, public names in `.pdxhackerspace.org`. Public names are served over HTTPS with Let's Encrypt certificates. Our router forwards ports 80 and 443 to the server.

- **dnsmasq** — local DNS inside the hackerspace. It maps names to IP addresses (generally the server's address on the LAN).

- **cloudflare-ddns** — after price hikes by our ISP we no longer use a static IP address. We host DNS at Cloudflare and use cloudflare-ddns to update `ddns.pdxhackerspace.org` whenever our public IP changes. Other domain names we use are CNAMEs for `ddns.pdxhackerspace.org`.

- **backrest** — backs up files from the server to our NAS, which copies backups offsite. We backup frequently changing files (`/opt/lib`) often, configuration (`/opt/docker`) less often, and logs (`/opt/log`) not at all. Live database files are excluded; use db-backup for those.

- **db-backup** — dumps live PostgreSQL and MariaDB databases to files on the NAS.

- **glances** — web-based system monitoring for the host and containers.

- **mdns-repeater** — repeats mDNS traffic between Docker networks and the host LAN so isolated containers can discover mDNS services.

- **upsd** — monitors UPS status and allows clean shutdown when battery is nearly exhausted.

- **postgresql** — shared PostgreSQL database used by many applications.

- **mariadb** — shared MariaDB (MySQL-compatible) database used by many applications.

- **adminer** — web interface to PostgreSQL and MariaDB.
