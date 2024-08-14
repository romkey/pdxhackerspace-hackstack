# Postgresql

These examples assume that the administrative user for Postgresql is `postgresql`. If you've used another name, substitute it for `postgresql`.

To create a user:
```
docker compose exec postgresql createuser -U postgresql -w USERNAME
```
this will prompt for a password.


To create a database:
```
docker compose exec postgresql createdb NAME -O OWNER_NAME;
```

To change a user or role's password:
```
docker compose exec postgresql psql -U postgresql
alter role NAME with password PASSWORD;
```

To grant privileges:
```
docker compose exec postgresql psql -U postgresql
grant all on database DATABASE to USER;
```

To dump database:
```
docker compose exec postgresql pg_dump -U postgresql DATABASE > database.psql
```

To restore database:
```
docker compose exec -T postgresql psql -U postgresql DATABASE < database.psql
```


