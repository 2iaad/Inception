COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /root/data

.PHONY: build up down clean fclean re

# build without running
build:
	mkdir -p $(DATA_DIR)/wordpress
	mkdir -p $(DATA_DIR)/mariadb
	$(COMPOSE) build

# does the building if no containers found
up:
	mkdir -p $(DATA_DIR)/wordpress
	mkdir -p $(DATA_DIR)/mariadb
	$(COMPOSE) up -d

down:
	$(COMPOSE) stop

# remove containers that been runnign in this compose but are no longer defined in the compose file
clean:
	$(COMPOSE) down --remove-orphans

fclean:
	$(COMPOSE) down -v --rmi all --remove-orphans
	docker network prune -f

re: fclean up