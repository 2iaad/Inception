up:
	docker compose -f srcs/docker-compose.yml up 
down:
	docker compose -f srcs/docker-compose.yml down -v --rmi all
build:
	mkdir -p /home/zderfouf/data/wp
	mkdir -p /home/zderfouf/data/db
	docker compose -f srcs/docker-compose.yml build
clean:
	docker system prune -af