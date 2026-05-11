## Scripts Explained

### `srcs/requirements/mariadb/tools/mariadb.sh`
```
Runs as ENTRYPOINT (PID 1 when container starts).

Step 1: start MariaDB in background (service mariadb start)
         — needed so we can run SQL commands against it
Step 2: sleep 5 — wait for the daemon to be ready
Step 3: run SQL to:
         CREATE DATABASE IF NOT EXISTS <MYSQL_DB>
         CREATE USER <MYSQL_USER>@'%' (allows connections from any host)
         GRANT ALL PRIVILEGES on that DB to that user
         FLUSH PRIVILEGES
Step 4: stop the background MariaDB
Step 5: relaunch with mysqld_safe --port=3306 --bind-address=0.0.0.0
         — this is the foreground process Docker watches
         — bind 0.0.0.0 so WordPress (another container) can connect
```

### `srcs/requirements/wordpress/wp-config.sh`
```
Runs as ENTRYPOINT (PID 1 when container starts).

Step 1: download wp-cli.phar from GitHub, install to /usr/local/bin/wp
Step 2: create /var/www/wordpress owned by www-data (775)
Step 3: if wp-config.php doesn't exist yet (fresh volume):
         wp core download         — pulls WordPress core files
         wp core config           — writes wp-config.php
                                    dbhost = mariadb:3306 (Docker DNS)
                                    dbname/dbuser/dbpass from .env
         wp core install          — runs WP installer, sets:
                                    site URL, title, admin user, admin pass
         wp user create           — adds a second (editor) user
Step 4: patch /etc/php/8.2/fpm/pool.d/www.conf
         changes: listen = /run/php/php8.2-fpm.sock
         to:      listen = 0.0.0.0:9000
         — required so NGINX (another container) can reach PHP-FPM over TCP
Step 5: launch php-fpm8.2 -F (foreground)
```

### `srcs/requirements/nginx/nginx.conf`
```
events {}   <- required block, left empty (defaults)

http {
  server {
    listen 443 ssl;             <- HTTPS only, port 443
    ssl_certificate  /etc/nginx/ssl/inception.crt;   <- baked at build time
    ssl_certificate_key /etc/nginx/ssl/inception.key;

    root  /var/www/wordpress;   <- shared volume with WordPress container
    index index.php;

    location ~ \.php$ {         <- any .php request gets forwarded
      fastcgi_pass wordpress:9000;  <- Docker DNS resolves "wordpress"
    }
  }
}
```
TLS cert is generated at image build time via `openssl req -x509`.
Country=MA, CN=localhost. Self-signed, so the browser will warn you.

---