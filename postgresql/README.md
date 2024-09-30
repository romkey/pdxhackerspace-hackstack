# Postgresql

Use the convenience script located in `bin/mkdb.sh` to create a database and its owner and the owner's password. While your current directory is the application's that needs Postgresql access run:

```
../postgresql/bin/mkdb.sh APPLICATION
```

Where `APPLICATION` is the name of the application.

This will:
1. create a database named `APPLICATION_db`
2. create a user which owns the database named `APPLICATION_user`
3. create a strong password for the user
4. if you run this from a directory other than postgresql's it will append a BACKUP_DATABASE URL to the .env file in that directory unless the .env file already has a BACKUP_DATABASE URL line
5. output the info for the database

Alternatively you can run commands to make the database and user yourself.


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


