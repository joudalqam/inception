# Developer documentation

## Environment setup

Use a Linux VM with Docker Engine, Docker Compose v2 supporting `pull_policy`,
Make, OpenSSL, and access to the Docker daemon. Storage instructions below assume
a local, systemd-managed, rootful Docker Engine, not Docker Desktop or a remote
Docker daemon.

If `srcs/.env` does not exist, copy `srcs/.env.example` to it. Configure:

| Variables | Purpose |
| --- | --- |
| `DOMAIN_NAME` | Hostname only, normally `jalqam.42.fr` |
| `HOST_DATA_PATH` | Docker data directory, normally `/home/jalqam/data`; use an unquoted absolute path without spaces |
| `MYSQL_DATABASE`, `MYSQL_USER` | Database and application account |
| `WP_TITLE` | Website title |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL` | Administrator identity; username must not contain `admin` |
| `WP_USER`, `WP_USER_EMAIL` | Separate author identity; defaults to `author` and `author@DOMAIN_NAME` for existing environment files |

Run `make secrets` to generate missing passwords. Existing nonempty files are
preserved and restricted to mode 600; empty files cause an error. Secret files
contain only the password, not username/password pairs. MariaDB currently
interpolates database credentials in initialization SQL: use simple alphanumeric
identifiers and avoid single quotes/backslashes in database passwords. Generated
hexadecimal passwords meet that constraint.

Add `VM_IP jalqam.42.fr` to the browser machine's hosts file. Substitute the
actual VM IP and learner domain. All source configuration is under `srcs/`;
service files are in `srcs/requirements/{mariadb,wordpress,nginx}/`. Local secrets
are under `secrets/`. The NGINX entrypoint generates its certificate inside the
container; there is no host certificate mount or `make certs` target. Recreating
NGINX generates a new certificate.

## Configure ordinary named-volume storage

Compose uses `inception_mariadb_data` and `inception_wordpress_data` as ordinary
Docker local volumes without bind options. Set the Docker daemon's `data-root`
to match `HOST_DATA_PATH`. An example is in `srcs/docker/daemon.json.example`:

```json
{"data-root": "/home/jalqam/data"}
```

On a new dedicated VM, create the directory with
`sudo mkdir -p /home/jalqam/data`, merge that key into `/etc/docker/daemon.json`
without discarding existing settings, and run `sudo systemctl restart docker`.
Changing the data root affects the whole Docker daemon: old resources become
unavailable until migrated or the setting is reverted. For an existing site,
back it up first using the next section. This configuration is a VM prerequisite;
Make does not edit system-wide Docker settings automatically.

Verify with `docker info --format '{{.DockerRootDir}}'`. `make data` checks the
root and rejects existing project volumes with custom driver options. With the
example root, persistent files reside at:

- `/home/jalqam/data/volumes/inception_mariadb_data/_data`
- `/home/jalqam/data/volumes/inception_wordpress_data/_data`

Confirm using `docker volume inspect inception_mariadb_data inception_wordpress_data`.
Normal container removal, recreation, and VM reboot preserve these volumes.

## Migrate existing bind-backed data

Inspect the old volumes to determine their actual host paths. The commands below
assume `/home/jalqam/data/mariadb` and `/home/jalqam/data/wordpress`; substitute
the old paths if different. Stop services before archiving database files:

```sh
make down
mkdir -m 700 "$HOME/inception-backup"
sudo tar -cpf "$HOME/inception-backup/mariadb.tar" -C /home/jalqam/data/mariadb .
sudo tar -cpf "$HOME/inception-backup/wordpress.tar" -C /home/jalqam/data/wordpress .
sudo chown "$(id -u):$(id -g)" "$HOME/inception-backup/"*.tar
chmod 600 "$HOME/inception-backup/"*.tar
tar -tf "$HOME/inception-backup/mariadb.tar" >/dev/null
tar -tf "$HOME/inception-backup/wordpress.tar" >/dev/null
```

Preserve the local secret files too. Configure and restart Docker as above. If
old volume definitions remain visible in the selected daemon root, inspect them
and remove only those backed-up old definitions:

```sh
docker volume inspect inception_mariadb_data inception_wordpress_data
docker volume rm inception_mariadb_data inception_wordpress_data
```

Skip that removal when the new root has no old volumes. Never remove restored
volumes. Build images and restore into empty ordinary volumes using the project's
own images and no bind mounts:

```sh
make build
make secrets
docker volume create inception_mariadb_data
docker volume create inception_wordpress_data
docker run --rm -i --network none --entrypoint tar \
  --mount type=volume,source=inception_mariadb_data,target=/var/lib/mysql \
  mariadb:inception -xpf - -C /var/lib/mysql < "$HOME/inception-backup/mariadb.tar"
docker run --rm -i --network none --entrypoint tar \
  --mount type=volume,source=inception_wordpress_data,target=/var/www/html \
  wordpress:inception -xpf - -C /var/www/html < "$HOME/inception-backup/wordpress.tar"
make
```

Keep the same database major version during migration. Verify posts, accounts,
and uploads before removing backups or old directories. Old host directories
are never imported or deleted automatically. Do not use `make fclean` to migrate.

## Build, operation, and cleanup

`make build` builds the three local service images, explicitly tagged
`mariadb:inception`, `wordpress:inception`, and `nginx:inception`. `make up`
checks storage, generates missing secrets, and starts Compose with `--build`.
Compose's `pull_policy: never` prevents pulling prebuilt service images; builds
still download the Debian base and packages. `make restart` runs down before up,
including with parallel Make.

```sh
make ps
make logs
make stop
make start
make down
docker compose -f srcs/docker-compose.yml config --quiet
docker volume inspect inception_mariadb_data inception_wordpress_data
```

`make clean` removes project containers/network and orphan containers, keeping
volumes. `make fclean` additionally removes project named volumes and service
images. It retains secrets and does not delete host directories, run global
pruning, or pull a helper image for cleanup.

## Startup and HTTPS behavior

MariaDB checks its temporary initialization server at most 30 times, limits each
ping to two seconds, and detects process exit. Signal/exit handlers stop and reap
the temporary server if setup fails. The final foreground server accepts TCP
connections. The Compose health check uses authenticated TCP SQL so the
socket-only initialization server cannot satisfy it prematurely.

WordPress limits database readiness to 60 SQL attempts, each with a three-second
command timeout and one-second retry delays. WP-CLI generates missing PHP
configuration safely, installs missing database tables, synchronizes `home` and
`siteurl` to `https://DOMAIN_NAME`, and creates the author if missing. Existing
account passwords are not reset. NGINX already passes `HTTPS=on` to PHP-FPM.
Embedded historical URLs in post content are not rewritten automatically.

## Validation

```sh
make
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs --tail=100
# WP-CLI needs an explicit path when invoked through docker exec.
docker compose -f srcs/docker-compose.yml exec wordpress wp core is-installed --path=/var/www/html --allow-root
docker compose -f srcs/docker-compose.yml exec wordpress wp option get home --path=/var/www/html --allow-root
docker compose -f srcs/docker-compose.yml exec wordpress wp option get siteurl --path=/var/www/html --allow-root
docker compose -f srcs/docker-compose.yml exec wordpress wp user list --fields=user_login,roles --path=/var/www/html --allow-root
curl -kI https://jalqam.42.fr
```

Check HTTPS, administrator login, the author account, and that only port 443 is
published. Create a post and upload an image; run `make down` followed by `make`
and verify persistence. Repeat after a VM reboot. Verify TLS 1.2/1.3 acceptance
and older-protocol rejection with a capable client. Inspect volumes to confirm
no bind options. Static and simulated checks do not replace these live tests.

## Submission note

The supplied Git repository already tracks local secrets, `.env`, and an editor
swap file. `.gitignore` prevents adding new matching files but cannot untrack
existing ones or erase history. Remove credentials from the submission and
rotate exposed values before publishing; coordinate database and WordPress
password changes with the existing installation.
