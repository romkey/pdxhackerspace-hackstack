# Philosophy

## Underlying System

Keep the underlying system hosting the servers as clean and unpolluted
as possible. Whenever possible, install software in a container
configured by this repository. The goal is to be able to easily spin
up a new instance on a fresh server without having to do extensive
configuration of the Linux system running the services.

## Separation of Concerns

Separate configuration, run time and persistent state, and logs. Store all of them consistently in order to make administration and backups as easy possible. Configuration is managed by this repository, with `.env` files holding configuration.

To this end, for each service we store:

configuration - `docker-compose.yml`, `.env` and configuration directories or files in its own directory in `/opt/docker`
run time and persistent state - `/opt/lib`
logs - `/opt/logs`
  
## Isolation

Isolate services from the Internet, local network and one another whenever reasonable. While we are not going to heroic efforts to secure the services, isolation will help reduce the impact that a misbehaving service might have, and will reduce the likelihood of the service being susceptible to mischief.

To this end, whenever possible we do not expose container ports. In some cases (like dnsmasq or rsyslog) there's no choice, but whenever it's possible we route
  traffic to the container through nginx-proxy-manager using a unique hostname, rather than directly expose them. This limits the

## Minimize

Many Docker Compose projects bundle their own database or other services. We prefer to use a single instance of each flavor of database - this simplifies management and backup and reduces overhead. The potential drawbacks are single point of failure and version skew. Postgresql is a tank and is unlikely to be the point of failure. If it is, it needs to get fixed ASAP. And both Postgresql and Mariadb have good histories with backwards compatability.

## Caveats

While we have tried to minimize dependencies on absolute pathnames, there may be places that we missed.

We've also tried to organize things so that `docker-compose.yml` files don't need to be modified but there may be places where this is unavoidable.

We're running on Debian 12 (bookworm) server with no GUI and as few extra packages installed as possible. This is unlikely to work on macOS or Windows without modification.
