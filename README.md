<div align="center">

<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" width="80" />
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/nginx/nginx-original.svg" width="80" />
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/wordpress/wordpress-plain.svg" width="80" />
<img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" width="80" />

## Overview

Small web infrastructure with **Docker Compose**, **NGINX**, **WordPress + PHP-FPM**, and **MariaDB**, hand-built from `debian:bookworm`, wired on a private bridge network reachable only through **TLS on port 443**(Port 80 is CLOSED, HTTP does not exist here :P). No pre-built images, no `latest` tags.


---

## Architecture

<img src="./diagram.png" width="800" />

</div>

---

## Startup Order

```
make up
  |
  +-- mkdir /root/data/wordpress   (host volume dirs)
  +-- mkdir /root/data/mariadb
  |
  +--> mariadb container starts
  |       mariadb.sh runs:
  |         1. start service (setup mode)
  |         2. create DB + user + grant
  |         3. stop service
  |         4. launch mysqld_safe (foreground, PID 1)
  |       healthcheck: mysqladmin ping every 7s
  |
  +--> wordpress container starts  (waits: mariadb healthy)
  |       wp-config.sh runs:
  |         1. download wp-cli
  |         2. if no wp-config.php:
  |              wp core download
  |              wp core config  (points to mariadb:3306)
  |              wp core install (creates admin + editor users)
  |         3. patch php-fpm to listen on 0.0.0.0:9000
  |         4. launch php-fpm8.2 -F (foreground, PID 1)
  |
  +--> nginx container starts  (waits: wordpress up)
          Dockerfile baked a self-signed cert at build time
          nginx.conf: listen 443 ssl, forward *.php -> wordpress:9000
          CMD: nginx -g "daemon off;" (foreground, PID 1)
```

---

## File Map

```
sysadmin-orbit/
├── Makefile                        <- build/run/clean commands
├── srcs/
│   ├── docker-compose.yml          <- networks, volumes, services
│   ├── .env                        <- secrets (git-ignored)
│   ├── .env.example                <- template for .env
│   └── requirements/
│       ├── mariadb/
│       │   ├── Dockerfile          <- installs mariadb-server
│       │   └── tools/mariadb.sh   <- init DB + run mysqld_safe
│       ├── nginx/
│       │   ├── Dockerfile          <- installs nginx + openssl, bakes TLS cert
│       │   └── nginx.conf          <- server config (443 ssl, fastcgi)
│       └── wordpress/
│           ├── Dockerfile          <- installs php-fpm, php-mysql, curl
│           └── wp-config.sh        <- wp-cli install + run php-fpm
```

---

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

## Volumes & Data Persistence

```
Host path               Docker volume name   Mounted in
/root/data/mariadb  --> mariadb (bind)    --> mariadb:/var/lib/mysql
/root/data/wordpress -> wordpress (bind)  --> wordpress:/var/www/wordpress
                                          --> nginx:/var/www/wordpress (read)
```

Both volumes use `driver: local` with `o: bind` — they are plain host directories
bind-mounted into the containers. Data survives `docker compose down` but is wiped
by `make fclean` (which does `rm -rf /root/data`).

---

## .env Variables

| Variable           | Used by        | Purpose                          |
|--------------------|----------------|----------------------------------|
| `MYSQL_DB`         | MariaDB, WP    | Database name                    |
| `MYSQL_USER`       | MariaDB, WP    | DB user WordPress connects as    |
| `MYSQL_PASSWORD`   | MariaDB, WP    | Password for that user           |
| `DOMAIN_NAME`      | WordPress      | Site URL (e.g. https://IP)       |
| `WP_TITLE`         | WordPress      | Site title                       |
| `WP_ADMIN_N/P/E`   | WordPress      | Admin username / password / email|
| `WP_U_NAME/EMAIL/PASS/ROLE` | WordPress | Second (editor) user        |

`.env` is git-ignored. Copy `.env.example` and fill in real values.

---

## Makefile Commands

| Command      | What it does                                                      |
|--------------|-------------------------------------------------------------------|
| `make build` | Creates `/root/data/{wordpress,mariadb}`, then `docker compose build` |
| `make up`    | `build` + `docker compose up -d`                                  |
| `make down`  | `docker compose down -v --rmi all` (stops, removes volumes+images)|
| `make clean` | `down` + `docker system prune -af`                                |
| `make fclean`| `down` + prune + `rm -rf /root/data` (wipes all data)             |
| `make re`    | `clean` + `build` + `up` (full rebuild from scratch)              |

---

## Key Rules (42 constraints)

- One service per container — no putting two processes in one image.
- No `latest` tags — all images tagged `:42`.
- No `network: host` or `--privileged`.
- Every service runs as PID 1 in the foreground (no `daemon on`).
- Port 80 is never opened — HTTP does not exist.
- Secrets live in `.env`, never baked into Dockerfiles.
- WordPress only starts after MariaDB passes its `mysqladmin ping` healthcheck.
