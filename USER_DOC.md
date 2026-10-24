
# Inception User Documentation

## Services Overview

The infrastructure consists of three services connected through a private Docker network called `inception`:

- **NGINX:** Provides the HTTPS entry point through host port `443`. It serves the WordPress website files and forwards PHP requests to PHP-FPM.
- **WordPress:** Runs WordPress with PHP-FPM, listening on container port `9000`. This service does not expose a port directly to the host.
- **MariaDB:** Stores and manages the WordPress database. It is accessible only through the internal Docker network and does not publish a host port.

NGINX is the only service exposed externally. WordPress and MariaDB communicate internally without direct access from outside the Docker network.

## Starting and Stopping the Project

Open a terminal at the root of the repository and prepare the environment:

```sh id="t8d1sq"
cp srcs/.env.example srcs/.env
# Check HOST_DATA_PATH in srcs/.env before starting.
make
```

The following commands can be used to control the infrastructure:

```sh id="u6b0q9"
make up       # Build the images and start the services
make ps       # Display the current service status
make logs     # View logs from the running services
make down     # Stop and remove the containers
make restart  # Restart the application stack
```

During the initial launch, startup may take longer because the required images and WordPress files need to be prepared.

The project uses a self-signed TLS certificate for development. When accessing the website for the first time, your browser will display a certificate warning. Verify that you are accessing your own development environment before proceeding.

## Accessing the Website and Administration Panel

Open the website using the domain configured in `srcs/.env`:

[https://jalqam.42.fr](https://jalqam.42.fr)

The actual address depends on the value of `DOMAIN_NAME`. Ensure that the domain points to your virtual machine's IP address.

During the initial setup, the project initializes the WordPress website and creates the administrator account.

To access the administration dashboard, visit:

[https://jalqam.42.fr/wp-admin/](https://jalqam.42.fr/wp-admin/)

Replace the domain in this URL if `DOMAIN_NAME` is configured differently.

The administrator username is defined by `WP_ADMIN_USER` in `srcs/.env`. The corresponding generated password is stored locally in `secrets/credentials.txt`.

## Managing Credentials

Use the following command to generate the required local secret files:

```sh id="5l7f6f"
make secrets
```

The command creates the following files:

- `secrets/db_root_password.txt`: Contains the MariaDB root account password.
- `secrets/db_password.txt`: Contains the password used by the WordPress database account.
- `secrets/credentials.txt`: Contains the WordPress administrator credentials.

These files are excluded from Git and are provided to the appropriate services as Docker secrets, accessible under `/run/secrets/`.

**Never commit or publicly share secret files.** Do not copy their contents into the `.env` file, Dockerfiles, documentation, or public logs.

The `make fclean` command removes generated secret files along with other project resources. Make sure you understand its cleanup behavior before running it.

The `srcs/.env` file is intended for ordinary configuration values, such as the domain name, database name, database username, and host storage path. Local override files, including `srcs/.env.local`, are also excluded from Git when configured in the repository's ignore rules.

## Checking Service Health

MariaDB uses a Docker Compose health check that runs `mariadb-admin ping` with the root password supplied through a secret.

WordPress waits for MariaDB to become healthy and performs an additional database readiness check during initialization. NGINX starts after the WordPress service has been created and provides the HTTPS endpoint.

To check the current state of the services, run:

```sh id="6a72dr"
make ps
docker compose -f srcs/docker-compose.yml ps
```

To investigate startup problems or other errors, inspect the service logs:

```sh id="o5w2lr"
make logs
docker compose -f srcs/docker-compose.yml logs <service>
```

Replace `<service>` with the name of the affected service, such as `nginx`, `wordpress`, or `mariadb`.

Reviewing the logs and container status is the first step when troubleshooting connection failures, database initialization problems, or services that fail to start.

