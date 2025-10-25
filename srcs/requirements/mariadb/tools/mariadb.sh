#!/bin/bash

service mariadb start
sleep 5

mariadb -h localhost --execute="
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`\g
        CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'\g
        GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO \`${MYSQL_USER}\`@'%'\g
        FLUSH PRIVILEGES\g"

service mariadb stop

mysqld_safe --port=3306 --bind-address=0.0.0.0 --datadir='/var/lib/mysql'