#!/bin/bash

# Download WP-CLI
curl    -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod   +x wp-cli.phar
mv      wp-cli.phar /usr/local/bin/wp
install --directory --mode=775 --owner=www-data --group=www-data /var/www/wordpress
cd      /var/www/wordpress

if [ ! -f "/var/www/wordpress/wp-config.php" ]; then
# Download WordPress core files
    wp core download --allow-root

# Create wp-config.php that specifies how to connect to the DB
wp  core config --dbhost="mariadb::3306" \
                --dbname="$MYSQL_DB" \
                --dbuser="$MYSQL_USER" \
                --dbpass="$MYSQL_PASSWORD" \
                --allow-root
# Install WordPress (site + add admin user to the data base linked previously)
wp  core install    --url="$DOMAIN_NAME" \
                    --title="$WP_TITLE" \
                    --admin_user="$WP_ADMIN_N" \
                    --admin_password="$WP_ADMIN_P" \
                    --admin_email="$WP_ADMIN_E" \
                    --allow-root
# Add more users
wp  user create "$WP_U_NAME" "$WP_U_EMAIL" \
                --user_pass="$WP_U_PASS" \
                --role="$WP_U_ROLE" \
                --allow-root
fi

# change listen port from unix socket to 9000
sed -i '36 s@/run/php/php7.4-fpm.sock@9000@' /etc/php/7.4/fpm/pool.d/www.conf
# create a directory for php-fpm
mkdir -p /run/php
# start php-fpm service in the foreground to keep the container running
/usr/sbin/php-fpm7.4 -F