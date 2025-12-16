# authentik-ak-outpost

This is a small server that works with Authentik to authorize user access to a variety of applications we use that have no authorization capabilities (for instance, ESPHome or Calibre).

To deploy this, copy `.env.example` to `.env` and set `AUTHENTIK_TOKEN`, then `docker compose up -d`.

## Configuring Authentik

For each service you want to authenticate for:

1. Configure an Authentik Application

Admin → Applications → Applications → Create with Provider

Name: application name

2. Provider → Proxy

Mode: `Forward auth (single application)`
External host: service URL (for instance, https://esphome.pdxhackerspace.org)
Proy backend fields empty

3. To restrict access, open Application → (tab) Bindings and attach a Group or Policy.

## Creating an Outpost

You only have to do this once. The Outpost is shared/reused among the services.

1. Admin → Applications → Outposts → Create

Type: Proxy
Integration: Docker
Applications: select the applications you want to use it

2 Bring up this container

## Configuring NGINX Proxy Manager

1. Advanced tab

Custom NGINX Configuration:

```
# Ask Authentik outpost if this request is authenticated/authorized
auth_request /outpost.goauthentik.io/auth/nginx;
error_page 401 = @ak_signin;

# (optional) forward identity to the app for logging
auth_request_set $ak_user  $upstream_http_x_authentik_username;
auth_request_set $ak_email $upstream_http_x_authentik_email;
proxy_set_header X-Authentik-Username $ak_user;
proxy_set_header X-Authentik-Email    $ak_email;

# WebSockets (needed by ESPHome and often helpful for others)
#proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# The outpost auth check shouldn't receive bodies
location = /outpost.goauthentik.io/auth/nginx {
  proxy_pass http://ak_outpost:9000/outpost.goauthentik.io/auth/nginx;
  proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
  proxy_pass_request_body off;
  proxy_set_header Content-Length "";
}

# Let the outpost handle login/start and set cookies
location /outpost.goauthentik.io/ {
  proxy_pass http://ak_outpost:9000/outpost.goauthentik.io/;
  proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
}

# Redirect unauthenticated users into SSO
location @ak_signin {
  internal;
  return 302 /outpost.goauthentik.io/start?rd=$scheme://$http_host$request_uri;
}
```

2. Custom locations

Add location `/outpost.goauthentik.io`

Forward to `http` `ak_outpost` `9000`
