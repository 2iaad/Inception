COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /root/data

.DEFAULT_GOAL := help

.PHONY: help build up down clean fclean re logs logs-nginx logs-mariadb logs-wordpress

help:
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════╗"
	@echo "║  Available Commands                                              ║"
	@echo "╠══════════════════════════════════════════════════════════════════╣"
	@echo "║  Core                                                            ║"
	@echo "║    make build     Build Docker images (no run)                   ║"
	@echo "║    make up        Build + start all services in detached mode    ║"
	@echo "║    make down      Stop all services                              ║"
	@echo "║    make re        Full clean + rebuild + up                      ║"
	@echo "║                                                                  ║"
	@echo "║  Cleanup                                                         ║"
	@echo "║    make clean     Stop + remove containers & orphans             ║"
	@echo "║    make fclean    clean + remove volumes, images & networks      ║"
	@echo "║                                                                  ║"
	@echo "║  Logs                                                            ║"
	@echo "║    make logs            All services logs (follow)               ║"
	@echo "║    make logs-nginx      Nginx logs                               ║"
	@echo "║    make logs-mariadb    MariaDB logs                             ║"
	@echo "║    make logs-wordpress  WordPress logs                           ║"
	@echo "╚══════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  Data directories:"
	@echo "  -> WordPress    $(DATA_DIR)/wordpress"
	@echo "  -> MariaDB      $(DATA_DIR)/mariadb"
	@echo ""

# ────────────────────────────────────────────────────────────────────────────────

build:
	mkdir -p $(DATA_DIR)/wordpress
	mkdir -p $(DATA_DIR)/mariadb
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) stop

clean: down
	$(COMPOSE) down --remove-orphans

fclean: clean
	$(COMPOSE) down -v --rmi all --remove-orphans
	docker network prune -f

re: fclean up

# ────────────────────────────────────────────────────────────────────────────────

logs:
	$(COMPOSE) logs --tail=50

logs-nginx:
	$(COMPOSE) logs nginx --tail=50

logs-mariadb:
	$(COMPOSE) logs mariadb --tail=50

logs-wordpress:
	$(COMPOSE) logs wordpress --tail=50