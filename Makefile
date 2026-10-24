COMPOSE := docker compose -f srcs/docker-compose.yml
HOST_DATA_ROOT := $(shell sed -n 's/^HOST_DATA_PATH=//p' srcs/.env 2>/dev/null | head -n1)

.PHONY: all build up down restart stop start logs ps clean fclean data secrets

all: up

build:
	$(COMPOSE) build

up: data secrets
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart: down
	$(MAKE) up

stop:
	$(COMPOSE) stop

start: data
	$(COMPOSE) start

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

data:
	@test -n "$(HOST_DATA_ROOT)" || { echo "error: srcs/.env is missing or has no HOST_DATA_PATH" >&2; exit 1; }
	@sh srcs/tools/check-storage.sh "$(HOST_DATA_ROOT)"

secrets:
	@sh srcs/tools/create-secrets.sh

clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down --remove-orphans --volumes --rmi all
