# bfg-repo-cleaner

Use this to purge files from git's history.

Especially useful with this repo which is full of files that might have
*cough* accidentally contained sensitive information.

## Installation

Run

`docker compose build`

in this directory.


## Usage

When you need to flush a file from the repository's history, first run these commands (`FILE` should be the filename)

```
git rm FILE
git commit -m 'removing FILE'
```

Then run

`docker compose run --entrypoint /bin/bash bfg-repo-cleaner`

This will get you a shell in the container. Once there navigate to the directory containing the file you deleted and run:

`java -jar /bfg/bfg.jar --delete-files FILE /opt/docker`

Note that you must run this in the file's directory, you cannot specify a pathname for `FILE`.

Once that's done, exit the container (`exit`). BFG may have written some files as root, so run these commands to get ownership and update the online repository:

```
chown -R YOURUSERNAME /opt/docker/.git
git push -f
```


