# PDX Hackerspace Docker Hackstack

This repo configures a set of services that PDX Hackerspace uses to provide services for its members and for infrastructure, administration and yes, fun and entertainment.

These are the core services we run on site.

# Services

## avahi-mdns

mDNS server - allows us to use .local domain

Not currently in use, unlikely to work correctly

## backrest

backrest web UI to Restic back up software

## cloudflare-ddns

Updates a Cloudflare domain name

## db-backup


## dns-masq

DNS server

## glances

System monitoring

## mariadb

Mariadb (successor to MySQL)

## mdns-repeater

Repeats mDNS traffic between a network interface and a Docker network. Allows containers to use private Docker networking instead of host network mode.

## nginx-proxy-manager


## portainer


## postgresql

Postgresql database

## redis


## upsd

UPS monitor and NUT (Network UPS Tool)

## watchtower

Automatically attempt to update docker containers when new images are released
