#!/bin/bash

curl    -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod   +x wp-cli.phar
mv      wp-cli.phar /usr/local/bin/wp
install --directory --mode=775 --owner=www-data --group=www-data /var/www/wordpress
cd      /var/www/wordpress

if [ ! -f "wp-config.php" ]; then

wp core download --allow-root

wp  core config --dbhost="mariadb:3306" \
                --dbname="$MYSQL_DB" \
                --dbuser="$MYSQL_USER" \
                --dbpass="$MYSQL_PASSWORD" \
                --allow-root

wp  core install    --url="$DOMAIN_NAME" \
                    --title="$WP_TITLE" \
                    --admin_user="$WP_ADMIN_N" \
                    --admin_password="$WP_ADMIN_P" \
                    --admin_email="$WP_ADMIN_E" \
                    --allow-root

wp  user create "$WP_U_NAME" "$WP_U_EMAIL" \
                --user_pass="$WP_U_PASS" \
                --role="$WP_U_ROLE" \
                --allow-root 
fi

sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 0.0.0.0:9000|' /etc/php/8.2/fpm/pool.d/www.conf

mkdir -p /run/php

/usr/sbin/php-fpm8.2 -F