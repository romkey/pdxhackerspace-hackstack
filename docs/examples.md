# Examples

On our primary server we're running a full stack. These services aren't things that end users would generally interact with, and gives us a sturdy foundation to run other applications on.

- Nginx Proxy Manager to provide reverse proxies for both local and public services. Each service has a hostname or domain name; Nginx Proxy Manager maps that name to the service. Local names end in `.ctrlh`, public names in `.pdxhackerspace.org`. Public names will always be served over HTTPS with certificates provided by Let's Encrypt, which Nginx Proxy Manager handles. Our router is configured to proxy ports 80 (HTTP) and 443 (HTTPS) to the server, where Nginx Proxy Manager handles them.

- dnsmasq provides local DNS service inside the hackerspace. It maps names to IP addresses (generally the single IP address of the server). When our 

- cloudflare-ddns - after price hikes by our ISP we no longer use a static IP address. We host our DNS for free at Cloudflare and use cloudflare-ddns to update `ddns.pdxhackerspace.org` whenever our public IP address changes. All other domain names that we use are CNAMEs for `ddns.pdxhackerspace.org`.

- backrest - we backup files off the server to our NAS, which copies the backups offsite. We backup frequently changing files (`/opt/lib`) frequently, configuration files (`/opt/docker`) less often and logs (`/opt/logs`) not at all. We exclude database storage for Postgresql, Mariadb and SQLite3 from these backups as it's not safe to back up live database files.

- db-backup - we use this script to back up live databases by dumping them to files on the NAS. 

- glances - 

- mdns-repeater - MDNS (Multicast Domain Name Service) is often used for service discovery and dynamic hostnames. MDNS Repeater allows us to isolate applications from one another and the real LAN that the server is connected to while making MDNS work by repeating MDNS packets between networks.

- upsd - this allows us to shut the system down cleanly if we're running off battery backup and the battery is near exhaustion.

- postgresql - Postgresql database, used by many applications

- mariadb - Mariadb (MySQL successor) database, used by many applications

- redis- Redis key/value store, used by many applications

- adminer - web interface to Postgresql and Mariadb




