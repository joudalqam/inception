
*This project was developed as part of the 42 curriculum by jalqam.*

# Inception

## Description

Inception is a compact and secure Docker-based environment designed to host WordPress. The infrastructure consists of three custom images based on Debian Bookworm:

- **NGINX** serves as the sole external access point, handling HTTPS connections on port 443.
- **WordPress** uses PHP-FPM and operates within the internal Docker network without publishing a host port.
- **MariaDB** provides database services for WordPress and remains inaccessible through published host ports.

All services communicate through a dedicated Docker bridge network named `inception`. Secure connections support TLSv1.2 and TLSv1.3 only. Sensitive database credentials are managed using Docker secrets rather than being embedded in image definitions or committed to the repository.

## Instructions

Install Docker Engine, Docker Compose support, and OpenSSL before launching the project. Then run:

```sh
cp srcs/.env.example srcs/.env
# Modify HOST_DATA_PATH in srcs/.env if necessary.
make
```

The Makefile prepares storage directories, generates local Docker secrets, creates a self-signed development certificate, builds the three service images, and starts the containers.

Open [https://jalqam.42.fr](https://jalqam.42.fr) in your browser. A security warning is expected because the certificate is self-signed.

Available Makefile commands:

```sh
make build       # Build images without starting containers
make up          # Build and start the services
make ps          # Display container status
make logs        # Follow service logs
make down        # Stop and remove containers
make clean       # Remove stopped containers
make fclean      # Remove containers, named volumes, secrets, and certificates
```

## Resources


- [Docker overview](https://docs.docker.com/get-started/overview/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Debian documentation](https://www.debian.org/doc/)
- [MariaDB documentation](https://mariadb.com/docs/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- [NGINX documentation](https://nginx.org/en/docs/)
- [WordPress documentation](https://developer.wordpress.org/)

- [WILL CONTAINER REPLACE HYPERVISOR](https://medium.com/@zybisys/will-container-replace-hypervisor-35015957a624) (Medium, Zybisys)

## AI Usage

AI tools were used to support brainstorming, troubleshooting, and configuration consistency. The project author remained responsible for implementation, verification, and understanding the codebase.

Testing procedures covering container behavior, TLS configuration, restart policies, persistent storage, and volume bindings are documented in [GUIDELINE_TESTING.md](GUIDELINE_TESTING.md).

## Technical Comparisons

### Virtual Machines vs. Docker

Virtual machines emulate hardware and run separate guest operating systems, each with its own kernel. They provide strong isolation but generally require more resources and take longer to start.

Docker containers share the host operating system's kernel while isolating processes, filesystems, networks, and resource usage. They are typically lightweight and start quickly, although their isolation depends on the host kernel and container runtime configuration.

### Secrets vs. Environment Variables

Environment variables are useful for ordinary configuration, such as `DOMAIN_NAME`, database names, and usernames. However, depending on the environment, they may be exposed through process inspection, Compose output, logs, or diagnostic tools.

Docker secrets provide a file-based method for supplying sensitive values through `/run/secrets/`. This project uses secrets for database passwords, avoiding their inclusion in Dockerfiles, image layers, and standard environment-variable listings.

### Docker Network vs. Host Network

A user-defined Docker bridge network enables private communication between services through Docker's internal DNS while controlling host port exposure.

In this project, WordPress connects to MariaDB through `mariadb:3306`, while NGINX communicates with PHP-FPM through `wordpress:9000`. Host networking removes the separate container network namespace and its associated network isolation, so it is not used.

### Docker Volumes vs. Bind Mounts

Docker-managed named volumes preserve application data independently of container lifecycles. Bind mounts connect specific host directories to paths inside containers, making the configuration more dependent on the host filesystem layout.

This project uses named volumes for MariaDB and WordPress data, with the local volume driver configured to store the data under `${HOST_DATA_PATH}/mariadb` and `${HOST_DATA_PATH}/wordpress`.

