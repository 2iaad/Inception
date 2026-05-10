COMPOSE = docker compose -f srcs/docker-compose.yml
# host side directories to inject into the container
DATA_DIR = /root/data

up: build
	$(COMPOSE) up -d

down:
	$(COMPOSE) down -v --rmi all

build:
	mkdir -p $(DATA_DIR)/wordpress
	mkdir -p $(DATA_DIR)/mariadb
	$(COMPOSE) build

clean: down
	docker system prune -af

fclean: down
	docker system prune -af --volumes
	rm -rf $(DATA_DIR)

re: clean build up