# postfix

Postfix mail relay for outbound email from Hackstack applications. The container hostname is `mail-relay` (service name remains `postfix`).

## Configuration

Copy `.env.example` to `.env` and configure relay settings:

```bash
cp .env.example .env
```

See `config/` for Postfix configuration files mounted into the container.

## Relay or no relay

Document whether this instance relays to an upstream SMTP provider or delivers locally. Update `.env` and `config/` accordingly.

## SPF

Ensure SPF records for domains you send mail from authorize this relay.

## Usage

### Starting the service

```bash
docker compose up -d
```

### Stopping the service

```bash
docker compose down
```

### Viewing logs

```bash
docker compose logs -f
```

Applications that send mail should join `postfix-net` and use hostname `mail-relay` (or service name `postfix` on that network).
