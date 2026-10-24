
# Inception Developer Documentation

## Setting Up the Environment

Install Docker Engine with Docker Compose v2 support, OpenSSL, and Git. Clone the repository and navigate to the project directory:

```sh
git clone <repository-url> Inception
cd Inception
cp srcs/.env.example srcs/.env
```

Edit `srcs/.env` to configure the required environment variables:

```dotenv
DOMAIN_NAME=jalqam.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
HOST_DATA_PATH=/home/jalqam/data
```

Ensure that the configured host directory is accessible to the current user. The `make data` command creates the required `mariadb` and `wordpress` directories.

## Project Structure

- `srcs/docker-compose.yml`: Defines the services, network, volumes, secrets, and restart policies.
- `requirements/mariadb`: Contains the MariaDB Dockerfile, configuration, and database initialization entrypoint.
- `requirements/wordpress`: Contains the WordPress installation, PHP-FPM configuration, and initialization entrypoint.
- `requirements/nginx`: Contains the NGINX configuration, TLS setup, and foreground entrypoint.
- `secrets/`: Stores locally generated secret files, which must be excluded from Git.
- `srcs/certs/`: Stores the local development certificate and private key. Generated certificate files must be excluded from version control.

## Building and Managing the Project

The Makefile runs Docker Compose using `docker compose -f srcs/docker-compose.yml`.

Available commands:

```sh
make secrets   # Generate database secret files
make certs     # Create a self-signed TLS certificate
make data      # Prepare host directories for persistent storage
make build     # Build the custom Docker images
make up        # Build and start all services
make ps        # Display service status
make logs      # Follow service logs
make down      # Stop and remove containers
make restart   # Restart the infrastructure
make clean     # Remove stopped containers
make fclean    # Remove containers, named volumes, secrets, and certificates
```

Docker Compose can also be used directly:

```sh
docker compose -f srcs/docker-compose.yml config
docker compose -f srcs/docker-compose.yml build
docker compose -f srcs/docker-compose.yml up -d
docker compose -f srcs/docker-compose.yml down
```

All three application images are built locally using Debian Bookworm as the base image. Prebuilt WordPress, NGINX, and MariaDB application images are not used.

## Container and Volume Management

The infrastructure consists of three services: `nginx`, `wordpress`, and `mariadb`.

Use these commands to inspect the running containers and persistent volumes:

```sh
docker compose -f srcs/docker-compose.yml ps
docker inspect nginx
docker volume ls
docker volume inspect inception_wordpress_data
docker volume inspect inception_mariadb_data
```

Keep the named volumes during routine development and updates, as they contain the persistent database and website data.

The `make fclean` command removes the named volumes along with other project resources. Use it only when you intend to perform a complete reset, since persistent application data may be permanently deleted.

## Persistent Data Storage

The project uses two Docker named volumes to preserve application data:

- **`inception_mariadb_data`**: Mounted at `/var/lib/mysql` inside the MariaDB container. Its data is stored on the host under `${HOST_DATA_PATH}/mariadb`.
- **`inception_wordpress_data`**: Mounted at `/var/www/html` inside the WordPress container. NGINX accesses the same website files through a read-only mount. The data is stored on the host under `${HOST_DATA_PATH}/wordpress`.

The local Docker volume driver maps these named volumes to the configured host directories. This allows the project to retain named-volume functionality while keeping its persistent data in the required location.

TLS certificates and Docker secret files are maintained separately from the application volumes. They must remain local and must not be committed to the public Git repository.
