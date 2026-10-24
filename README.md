*This project has been created as part of the 42 curriculum by jalqam.*

# Inception

## Description

This project hosts WordPress using three custom Debian Bookworm images on a
Linux virtual machine. NGINX accepts HTTPS connections on port 443, WordPress
runs through PHP-FPM, and MariaDB stores the database. The services communicate
on the `inception` bridge network. Only NGINX publishes a host port, and it
allows TLS 1.2 and 1.3.

## Instructions

Install Docker Engine, Docker Compose v2, Make, and OpenSSL on the VM. Follow
[DEV_DOC.md](DEV_DOC.md) to configure Docker storage before first startup or
migrate existing data. Copy `srcs/.env.example` to `srcs/.env` only if you do not
already have a local configuration. Set the learner domain and storage path,
map `jalqam.42.fr` to the VM's IP on the browser machine, then run `make`.

`make` checks storage, generates missing secret files without replacing existing
passwords, builds the images, and starts the services. NGINX generates its
self-signed certificate inside its container. Open `https://jalqam.42.fr` and
trust the local development certificate. Daily operation is explained in
[USER_DOC.md](USER_DOC.md).

```sh
make build      # Build images only
make up         # Check storage, prepare secrets, build, and start
make stop       # Stop existing containers
make start      # Start existing containers
make restart    # Recreate containers, preserving volumes
make ps         # Show service status
make logs       # Follow logs
make down       # Remove containers/network, preserving volumes
make clean      # Remove containers/network and project orphan containers
make fclean     # Delete project containers, volumes, and service images
```

`fclean` deletes persistent application data. It preserves local secrets and
never runs a global Docker prune or removes arbitrary host directories.

## Project description

Each service has a Dockerfile, configuration, and entrypoint under
`srcs/requirements/`. Compose builds `mariadb:inception`, `wordpress:inception`,
and `nginx:inception` locally; it does not pull prebuilt service images. Each
entrypoint finishes by executing the foreground daemon as PID 1.

MariaDB initializes its database and application account. WordPress checks
application-account database access, creates missing configuration with WP-CLI,
completes installation, and creates a separate author account. It synchronizes
saved site URLs to HTTPS on every startup. NGINX passes the HTTPS status to
PHP-FPM. Startup failures stop initialization instead of serving an incomplete
installation. Services restart after crashes unless explicitly stopped.

The two ordinary named volumes have no bind driver options. Docker's `data-root`
must match `HOST_DATA_PATH` (normally `/home/jalqam/data`); see the developer guide
for setup and migration. NGINX reads the WordPress volume without write access.

| Comparison | Project choice |
| --- | --- |
| Virtual machines vs Docker | A VM has a guest kernel; containers share their host kernel and isolate processes. This project runs Docker inside the required VM. |
| Secrets vs environment variables | Environment variables hold ordinary configuration. Passwords are supplied through mounted Docker secret files, which must still be protected on the host. |
| Docker network vs host network | The bridge network provides service-name resolution and separate container networking. Host networking shares the host network namespace and is not used. |
| Docker volumes vs bind mounts | Named volumes are managed by Docker and outlive containers. Bind mounts reference chosen host paths directly. This project uses ordinary named volumes with no bind options. |

## Resources

- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Docker daemon configuration](https://docs.docker.com/engine/daemon/)
- [Docker Compose](https://docs.docker.com/compose/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB documentation](https://mariadb.com/docs/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)

AI assisted with the startup review and fixes, WordPress configuration and user
creation, readiness checks, certificate storage, volume configuration, image
tags, Makefile cleanup, documentation, and simulated validation. The learner
must review, understand, and test these changes on the evaluation VM. Mock and
static checks do not establish that the complete infrastructure works live.
