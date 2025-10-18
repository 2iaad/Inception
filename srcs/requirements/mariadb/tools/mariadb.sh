#!/bin/bash

#mariadb start
service mariadb start
sleep 5

#mariadb config
mariadb -h localhost --execute="
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`\g
        CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'\g
        GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO \`${MYSQL_USER}\`@'%'\g
        FLUSH PRIVILEGES\g"

#mariadb restart -> Shutdown mariadb to restart with new config
service mariadb stop

# Restart mariadb with new config in the background to keep the container running
mysqld_safe --port=3306 --bind-address=0.0.0.0 --datadir='/var/lib/mysql'