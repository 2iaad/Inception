up:
	docker compose -f srcs/docker-compose.yml up -d
down:
	docker compose -f srcs/docker-compose.yml down -v --rmi all
build:
	mkdir -p /home/zderfouf/data/wordpress
	mkdir -p /home/zderfouf/data/mariadb
	docker compose -f srcs/docker-compose.yml build
clean:
	docker system prune -af