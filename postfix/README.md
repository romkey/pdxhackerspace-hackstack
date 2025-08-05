# Postfix Mail Relay

This service uses Postfix to operate a mail relay which forwards mail from other services to a relay service. It is not a general Mail Transfer Agent and is not meant for receiving or managing incoming email.

With some effort you may be able to find a free or low cost service.

Running this mail relay allows you to configure only a single service with the credentials for the external mail relay service rather than configure each individual application with them. That reduces the likelihood they'll be compromised, and if you ever need to change them there's only a single place that needs to be done.

See [bokysan/docker-postfix](https://github.com/bokysan/docker-postfix) for more information.

## Relay Or No Relay

It's likely that your ISP blocks port 25, which means you'll need to forward mail to an external relay. Some mail services may provide free tiers; a web search will help turn those up.

## SPF

Adding SPF records to the DNS lets mail servers confirm that mail was sent from a server that's allowed to send email on this domain's behalf. Your mail relay service should provide assistance with this. Without correct SPF records you may find that your outgoing mail bounces or just silently fails to arrive at its destination.

## Usage

To start the service:
```
docker compose up postfix -d
```
To check the mail queue:
```
docker compose exec postfix mailq
```

To create credentials for SMTP clients that want to use the relay:
```
echo PASSWORD | docker compose exec postfix saslpasswd2 -c -u ctrlh USERNAME
```
Note that the account is `USERNAME@ctrlh` in this case - using a domain name is necessary becsause intermediate mail relays mail drop mail with unqualified names in it.

Each service should have its own credentials so that it can be managed independently of other services.


To test credentials:
```
docker compose exec testsaslauthd -u USERNAME@DOMAIN -p PASSWORD
```
