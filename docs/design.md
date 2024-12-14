# Philosophy

Hackstack's priorities are:
- consistency
- ease of maintenance
- ease of disaster recovery

Hackstack is designed specifically for a hacker/makerspace type of
environment and recognizes that the needs and resources of such an
environment are very different from those of a business selling
web-based services.

Hacker/Makerspaces are generally smallish, low resourced
organizations. They:
- have memberships (users) which more likely number in the hundreds
  rather than hundreds of  thousands to millions
- offer services which may reasonably be only accessible on-site
- most likely do not have the resources to buy modern server hardware
  (and in fact may be running on scavenged or reclaimed hardware)
- most likely do not have the resources to have an on call tech
  support or IT staff but rather a few volunteers that keep things
  chugging along

### Anti-goals

Recognizing these conditions helps us understand some
anti-goals. These spaces do not need services that:
- scale
- migrate easily or transparently between nodes
and they do not need the overhead of running and maintaining systems
that offer those as primary features.

### Hardware

Because Hacker/Makerspaces often use older hardware they are subject
to a higher likelihood of hardware failure than businesses would
generally anticipate while having fewer resources to manage
failures. This dictates that overall design favor ease of disaster
recovery and keeping resource requirements minimal.

### Consistency

There is little consistency to how applications are offered online
using Docker compose files. Naming, port allocation, filesystem use
all vary tremendously. From a maintenance perspective having to figure
out how each individual application is set up can be a collosal
headache when they're all different. Therefore Hackstack provides a
set of guidelines as to how applications will be installed, similar to
how Linux has done for decades. Once a maintainer is familiar with
them they can easily inspect and manage any Hackstack application.

## Underlying System

Keep the underlying system hosting the servers as clean and unpolluted
as possible. Whenever possible, install software in a container
configured by this repository. The goal is to be able to easily spin
up a new instance on a fresh server without having to do extensive
configuration of the Linux system running the services.

## Separation of Concerns

Separate configuration, run time and persistent state, and logs. Store
all of them in consistent locations for each application in order to
make administration and backups as easy possible. Docker configuration is
managed by this repository, with `.env` files holding
application-specific configuration when possible.

To this end, for each service we store:

configuration - `docker-compose.yml`, `.env` and configuration directories or files in its own directory in `/opt/docker`
run time and persistent state - `/opt/lib`
logs - `/opt/logs`
  
## Isolation

Isolate services from the Internet, local network and one another
whenever reasonable. While we are not going to heroic efforts to
secure the services, isolation will help reduce the impact that a
misbehaving service might have, and will reduce the likelihood of the
service being susceptible to mischief.

To this end, whenever possible we do not expose container ports. In
some cases (like dnsmasq or rsyslog) there's no choice, but whenever
it's possible we route traffic to the container through
nginx-proxy-manager using a unique hostname, rather than directly
expose them. This limits the

## Minimize

Many Docker Compose projects bundle their own database or other
services. We prefer to use a single instance of each flavor of
database - this simplifies management and backup and reduces
overhead. The potential drawbacks are single point of failure and
version skew. Postgresql is a tank and is unlikely to be the point of
failure. If it is, it needs to get fixed ASAP. And both Postgresql and
Mariadb have good histories with backwards compatability.

## Caveats

While we have tried to minimize dependencies on absolute pathnames, there may be places that we missed.

We've also tried to organize things so that `docker-compose.yml` files don't need to be modified but there may be places where this is unavoidable.

We're running on Debian 12 (bookworm) server with no GUI and as few extra packages installed as possible. This is unlikely to work on macOS or Windows without modification.
