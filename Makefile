COMPOSE = docker compose -f ./srcs/docker-compose.yml
DATA_PATH = /home/axelpeti/data

all: up

up:
	mkdir -p ${DATA_PATH}/wordpress
	mkdir -p ${DATA_PATH}/mariadb
	$(COMPOSE) up -d --build
	sudo chown -R axelpeti:axelpeti ${DATA_PATH}

down:
	$(COMPOSE) down

re: clean
	mkdir -p ${DATA_PATH}/wordpress
	mkdir -p ${DATA_PATH}/mariadb
	$(COMPOSE) up -d --build
	sudo chown -R axelpeti:axelpeti ${DATA_PATH}

logs:
	$(COMPOSE) logs -f --tail=100

status:
	$(COMPOSE) ps

clean:
	sudo rm -rf ${DATA_PATH}/wordpress
	sudo rm -rf ${DATA_PATH}/mariadb
	$(COMPOSE) down -v

fclean: clean
	${COMPOSE} down --rmi all --volumes
	docker system prune -af --volumes

.PHONY: all up down re logs status clean fclean