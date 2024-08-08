# Contributing

Hackstack's top priority to be a snapshot of the software that we run on our server at PDX Hackerspace, shared to help others bring up applications that we found useful.

We don't intend it as any kind of ubiquitous or universal guide to server software. If you would like to contribute an application to it (or if a member would like to run an application on our server), we'd ask that it follow these guidelines. This will help keep the server organized, make it easier to manage a disparate set of applications, and let the applications obtain maximum benefit from running on it.

Hackstack applications all follow a set of conventions that dictate how they store data, publish network ports, use databases, are configured and backed up, and interact with one another. By following conventions the system stays manageable and organized; we know where everything lives and how it works, instead of being a haphazard collection of Docker and compose files that all do everything differently.

## Docker Compose

All services are managed by Docker Compose. The service should include a docker-compose.yml file in a directory at the root of the repository.

As a rule we try to allow users to customize the installation as much as possible without modifying the compose file. Obviously this isn't always possible but we strongly prefer doing so when possible. This allows the user a change to potentially be able to simply pull new versions of the hackstack to gain new applications.

## Volumes and Directory Layout

Docker Compose can specify external directories or Docker volumes to be mounted inside the container. We use a specific organization for volumes (`APPNAME` is the name of the application):

- any configuration data will be stored in a directory called `config` in the directory containing the `docker-compose` file
- any runtime data, state information, sqlite3 databases - anything that maintains the state of the application and which must be preserved across runs - will be stored in `../../lib/APPNAME`
- log files go in `../../log/APPNAME`
- transient runtime files, like caches or FIFOs, go in `../../run/APPNAME`

For instance, a `docker-compose.yml` might contain a `volumes` definition that looks like this:
```
    volumes:
      - ./config:/config
      - ../../lib/myapp:/var/lib/myapp
      - ../../log/myapp:/var/log/myapp
      - ../../run/myapp:/cache
```

By separating the kinds of data the application uses we can intelligently automatically back up its files, and ignore storage that doesn't need to be backed up like log files and transient runtime files.

We install the hackstack under `/opt/docker`. By using relative pathnames we may allow users to install in other locations without modifying the compose files, though there may be dependencies that will break this.

## Ports

Any application with a web interface should present the interface through `nginx-reverse-proxy` and not publish its ports directly. In general we will comment out any `port` definitions in compose files but leave them there as documentation. As long as the application uses the `nginx-proxy-network`, `nginx-reverse-proxy` will be able to access it by its Docker hostname. This also allows select applications to be made public on the Internet.

There are some applications, like mosquitto - an MQTT broker - which absolutely must have ports published, which we allow when necessary.

In general when you bring up an application under Hackstack you'll want to not comment out the ports to get it running, then comment them out for production use.

Requring the use of `nginx-reverse-proxy` means that each application is reached via a name, not a port number on a our server. This reduces the dependency on the particular server (the application could migrate to a different server and keep its name) and also reduces the chaos of published port numbers when you install many applications that may all want to use the same port.

If you do publish ports directly, be aware that Docker's networking and the commonly used `ufw` firewall don't play well together. Ports published by Docker will bypass `ufw`. You may easily think you've locked up open ports behind the firewall and don't need to think about them when Docker has made them available.

## Networks

We isolate compose projects on networks of related applications as much as possible. For instance, Piper, Whisper, Openwaakeword and Matter are all used by Home Assistant and no other applications, so Home Assistant creates its own network and each of these applications uses that network.

Isolation reduces possible conflicts and helps reliability and security by putting barriers between unrelated applications.

Hackstack ships with these networks created by its applications:

```
frigate-net
hass-net
mariadb-net
mdns-net
mosquitto-net
nginx-proxy-net
postgres-net
```

In particular note that we never use host networking if we can avoid it. This helps isolate the application and avoids cluttering the host's network port space.

Not using host networking does mean that applications won't see multicast and broadcast packets; in particular this breaks mDNS. As a fix Hackstack includes an application called `mdns-relay` which repeats mDNS traffic between the host's external network and its own Docker network. Any application that wishes to see mDNS traffic should include `mdns-net` in its network service definitions.

## Databases

Many applications require the use of Postgresql or MariaDB (MySQL). Often their compose files will include service definitions for those databases. That's great if you're an inexperienced user bringing up just that application, but you can quickly clutter your server with many separate instances of the databases, which is a maintenance headache and a waste of resources.

All applications should use the instance of Postgresql or MariaDB that is already running in the Hackstack. Any service definitions for bundled databases should be removed and the application should be configured to use the shared database. The 

If it's absolutely necessary that an application be pinned to a specific version of a database then of course that's acceptable, but both Postgresql and MariaDB have excellent backwards compability

We recognize the "single point of failure" argument but in particular, Postgresql is a tank and if it's failed then server maintainers have immediate issues they need to deal with that are more important than any one application.

## Environment and Configuration

We use `.env` files to configure the actual applications. Environment variables should always be defined in `.env` files and never in compose files. This allows the application to be configured without modifying the compose files. It also keeps sensitive information out of compose files and hence out of the Hackstack repository.

In order to keep them out of the repo, Hackstack's `.gitignore` file ignores `.env` files. Each application should include a `.env.example` file with everything that `.env` would include but all credentials, API keys and other sensitive information redacted.

Sometimes it may be necessary to reference an environment variable inside a compose file. You can generally do that using `"${VARIABLE_NAME}"` syntax in the compose file. For instance, in z-wave we do this to pass the device name in an environment variable:
```
    devices:
      - "${CONTROLLER_DEVICE}:/dev/zwave"
```
In this case we define `CONTROLLER_DEVICE` in the `.env` file:
```
CONTROLLER_DEVICE=/dev/serial/by-id/usb-0658_0200-if00
```
(obviously your definition may vary)

To write compose files to do this, copy any variable definitions to `.env` and remove them and the `environment` section from the file. Add this in its place:
```
    env_file:
	  - ./.env
```

## Backup

Persistent runtime files stored in `../../lib/APPNAME` are automatically backed up by `backrest`.

Unfortunately backing up live database storage doesn't work as the files may easily be in an inconsistent state.

The `db-backup` program looks for a  `.env` file in each application directory. If it finds one, it looks for a variable called `BACKUP_DATABASE_URLS`. This variable should contain a comma-separated list of quoted database URLs. It does a simple database dump for each database URL it finds, keeping the five most recent backups. This doesn't work well for very large databases; in that case we recommend rolling a custom backup solution that's appropriate for the specific database.

In our case, our server is named `chaos`; backups are done to `/backups/chaos/databases` and look something like this:
```
/backups/chaos/databases/calibre-web
1 -rw-r--r-- 1 3001 3001 91 Aug  6 17:23 backup-metadatab-20240806172303.sql.bz2
1 -rw-r--r-- 1 3001 3001 91 Aug  6 18:23 backup-metadatab-20240806182302.sql.bz2
1 -rw-r--r-- 1 3001 3001 91 Aug  6 19:23 backup-metadatab-20240806192303.sql.bz2
1 -rw-r--r-- 1 3001 3001 91 Aug  6 20:23 backup-metadatab-20240806202302.sql.bz2
1 -rw-r--r-- 1 3001 3001 91 Aug  6 21:23 backup-metadatab-20240806212302.sql.bz2
/backups/chaos/databases/frigate
7780 -rw-r--r-- 1 3001 3001 7956285 Aug  6 17:23 backup-frigate-20240806172303.sql.bz2
7812 -rw-r--r-- 1 3001 3001 7987908 Aug  6 18:23 backup-frigate-20240806182302.sql.bz2
7940 -rw-r--r-- 1 3001 3001 8122465 Aug  6 19:23 backup-frigate-20240806192303.sql.bz2
7940 -rw-r--r-- 1 3001 3001 8119166 Aug  6 20:23 backup-frigate-20240806202302.sql.bz2
7924 -rw-r--r-- 1 3001 3001 8103817 Aug  6 21:23 backup-frigate-20240806212302.sql.bz2
```

We backup to a network filesystem shared by our NAS which can automatically sync the backups off-site.

Database URLs look like this:

MariaDB - `BACKUP_DATABASE_URLS=mysql://DATABASE_USERNAME:DATABASE_PASSWORD@DATABASE_HOSTNAME:3306/DATABASE_NAME`
Postgresql - `BACKUP_DATABASE_URLS=postgresql://DATABASE_USERNAME:DATABASE_PASSWORD@DATABASE_HOSTNAME:5432/DATABASE_NAME`
SQLite3 - `BACKUP_DATABASE_URLS=sqlite:////opt/lib/frigate/config/frigate.db`

For MariaDB the database hostname should be `mariadb`; for PostgreSQL it should be `postgresql`.

Please be sure to include these URLs in the application's `.env.example` file with the credentials redacted.

# Updates

We use Watchtower to keep Docker images up to date. It will pull new images nightly and restart any updated applications automatically. Watchtower supports a variety of notification methods; we notify to a Slack channel.

You can tell Watchtower to ignore an application by adding a label to it:
```
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
```
(in this case "centurylinklabs" is in the label because they own Watchtower)

You might do this because you don't want an application updated or because it's a locally built application and there is no image to pull.

