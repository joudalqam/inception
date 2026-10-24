NAME := inception
COMPOSE := docker compose -f srcs/docker-compose.yml
HOST_DATA_ROOT := $(shell grep '^HOST_DATA_PATH=' srcs/.env 2>/dev/null | head -n1 | cut -d= -f2)

.PHONY: all build up down restart logs ps clean fclean data

all: up

build: data
	$(COMPOSE) build

up: data
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

data:
	@test -n "$(HOST_DATA_ROOT)" || { echo "error: srcs/.env is missing or has no HOST_DATA_PATH" >&2; exit 1; }
	@mkdir -p "$(HOST_DATA_ROOT)/mariadb" "$(HOST_DATA_ROOT)/wordpress"

clean:
	$(COMPOSE) down --remove-orphans

fclean: clean
	@docker volume rm $(NAME)_wordpress_data $(NAME)_mariadb_data 2>/dev/null || true
	@if [ -n "$(HOST_DATA_ROOT)" ]; then \
		if [ -e "$(HOST_DATA_ROOT)/mariadb" ] || [ -e "$(HOST_DATA_ROOT)/wordpress" ]; then \
			echo "Removing host data directories..."; \
			docker run --rm --user 0:0 --entrypoint /bin/rm \
				-v "$(HOST_DATA_ROOT):/data" \
				alpine:3.20 -rf /data/mariadb /data/wordpress \
				|| { echo "error: cannot remove host data directories; remove them manually (e.g. with sudo)" >&2; exit 1; }; \
		fi; \
	fi
