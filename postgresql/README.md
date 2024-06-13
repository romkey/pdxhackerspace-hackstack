# Postgresql

To create a database:
```
docker compose exec postgresql psql -U postgresql
create database NAME;
```

To create a user:
```
docker compose exec postgresql psql -U postgresql
create role NAME with password PASSWORD;;
```

`role` disallows login by default. Use `user` to allow login.

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


