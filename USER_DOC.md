# User documentation

## Services and access

NGINX provides HTTPS on port 443; WordPress provides publishing and account
management through PHP-FPM; MariaDB stores users, posts, and settings. The
database and PHP-FPM have no published host ports.

Map `jalqam.42.fr` to the VM's address in the browser machine's hosts file.
Visit `https://jalqam.42.fr` for the website and
`https://jalqam.42.fr/wp-admin/` for administration. Use the domain in
`srcs/.env` if customized. NGINX creates a self-signed development certificate,
so the browser requires you to trust it. HTTP on port 80 is not provided.

## Start and stop

Complete the one-time setup in [DEV_DOC.md](DEV_DOC.md), then use:

```sh
make           # Check storage, generate missing secrets, build, and start
make ps        # Show service status
make logs      # Follow logs
make stop      # Stop containers
make start     # Start existing containers
make down      # Remove containers/network while preserving data
make restart   # Recreate services while preserving data
```

Use `make` after `make down`. First startup takes longer while images and the
website are prepared. `make clean` also preserves data, but `make fclean`
deletes the database and website volumes. Local secrets are preserved.

## Credentials

`make secrets` creates missing files without replacing existing passwords:

- `secrets/db_root_password.txt`: MariaDB root password.
- `secrets/db_password.txt`: WordPress database account password.
- `secrets/credentials.txt`: WordPress administrator password only.
- `secrets/wp_user_password.txt`: WordPress author password.

The administrator username is `WP_ADMIN_USER` in `srcs/.env`; the author is
`WP_USER` (default `author`). Keep the usernames distinct. The administrator
username must not contain `admin` in any capitalization.

Use WordPress's Users page to change existing account passwords. Editing a
secret file does not reset existing WordPress accounts. Database password
changes also require updating the MariaDB account and persisted `wp-config.php`.
Coordinate those changes instead of replacing secrets and restarting blindly.

Keep secrets and local environment files private. Ignore rules prevent new
secret files from being added normally, but do not remove files already tracked
in Git. This supplied repository contains tracked secret files; those require
separate remediation before submission.

## Check health

```sh
make ps
docker compose -f srcs/docker-compose.yml logs --tail=100 mariadb wordpress nginx
docker compose -f srcs/docker-compose.yml exec wordpress wp core is-installed --path=/var/www/html --allow-root
curl -kI https://jalqam.42.fr
```

MariaDB should be healthy, all containers should remain running without repeated
restarts, and the site and administrator login should work. `curl -k` accepts the
self-signed development certificate. MariaDB's health check runs an authenticated
SQL query over TCP using the WordPress database account; WordPress also checks its own database account before setup.

For storage errors, follow the developer guide rather than deleting data. For
database failures, check MariaDB logs and the configured account/secret files.
Do not publish secrets or diagnostic output containing passwords.
