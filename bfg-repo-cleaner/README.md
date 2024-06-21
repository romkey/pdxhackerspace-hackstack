# bfg-repo-cleaner

Use this to purge files from git's history.

Especially useful with this repo which is full of files that might have
*cough* accidentally contained sensitive information.

```
git rm file
git commit -m 'removing file'
docker compose run bfg-repo-cleaner --delete-files file
git push -f
```

docker compose run --entrypoint /bin/bash bfg-repo-cleaner

java -jar /bfg/bfg.jar --delete-files .env.example ..
