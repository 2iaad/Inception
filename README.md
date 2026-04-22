<div align="center">

# Inception

**System administration from scratch — containerized the right way.**

A 42 School project that builds a small, secure web infrastructure using **Docker Compose**, **NGINX**, **WordPress + PHP-FPM**, and **MariaDB** — each service isolated in its own hand-built container, wired together over a private network, and reachable only through TLS.

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![NGINX](https://img.shields.io/badge/NGINX-009639?style=for-the-badge&logo=nginx&logoColor=white)
![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![Debian](https://img.shields.io/badge/Debian_Bookworm-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![TLS](https://img.shields.io/badge/TLS_1.2%2F1.3-4CAF50?style=for-the-badge&logo=letsencrypt&logoColor=white)
![42](https://img.shields.io/badge/42_Network-000000?style=for-the-badge&logo=42&logoColor=white)

</div>

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Makefile Commands](#makefile-commands)
- [Environment Variables](#environment-variables)
- [Services](#services)
- [Networking & Security](#networking--security)
- [Troubleshooting](#troubleshooting)
- [Author](#author)

---

## Overview

**Inception** teaches you how to architect production-style infrastructure using containerization. The challenge: set up a working WordPress site that lives behind an NGINX reverse proxy with TLS, backed by a MariaDB database — without using any pre-built application images. Every container is built from a **Debian Bookworm** (or Alpine) base image, configured by hand.

### Core Rules

- One service per container.
- No `latest` tags, no `--link`, no `network: host`, no `network_mode: host`.
- No infinite loops or hacks like `tail -f` as an entrypoint — services run as **PID 1** in the foreground.
- Volumes live on the host under `/home/<login>/data/`.
- The only exposed port is **`443`** (HTTPS with TLS 1.2 / 1.3). Plain HTTP is forbidden.
- Secrets live in a `.env` file, **never** in the Dockerfiles or the compose file.

---

## Architecture

```
                    ┌───────────────────────────────────────────────┐
                    │               Host Machine                    │
                    │                                               │
   Client ──443──▶  │   ┌─────────┐      ┌─────────────┐           │
   (HTTPS)          │   │  NGINX  │─────▶│  WordPress  │           │
                    │   │  (TLS)  │ 9000 │   PHP-FPM   │           │
                    │   └─────────┘      └──────┬──────┘           │
                    │                           │ 3306              │
                    │                           ▼                   │
                    │                    ┌─────────────┐           │
                    │                    │   MariaDB   │           │
                    │                    └─────────────┘           │
                    │                                               │
                    │     Network: inception (bridge, isolated)     │
                    │     Volumes: /home/<login>/data/{wp,db}       │
                    └───────────────────────────────────────────────┘
```

Three containers, one private bridge network, two bind-mounted volumes. That's it.

---

## Project Structure

```
Inception/
├── Makefile                        # up / down / build / clean
├── srcs/
│   ├── docker-compose.yml          # orchestrates the three services
│   ├── .env                        # secrets (not committed)
│   └── requirements/
│       ├── mariadb/
│       │   ├── Dockerfile
│       │   └── tools/mariadb.sh    # DB + user bootstrap
│       ├── nginx/
│       │   ├── Dockerfile
│       │   └── nginx.conf          # TLS + FastCGI to WordPress
│       └── wordpress/
│           ├── Dockerfile
│           └── WpConfig.sh         # wp-cli install + php-fpm
└── README.md
```

---

## Requirements

- **Docker** 20.10+
- **Docker Compose** v2 (`docker compose`, not `docker-compose`)
- **make**
- A Linux host (tested on the 42 campus VMs / Debian) with `sudo` privileges
- **2+ GB RAM** free and a few GB of disk

> **Heads-up:** the compose file binds volumes to `/home/zderfouf/data/...`. If your login differs, update `srcs/docker-compose.yml` and the `Makefile` to point at your own home directory.

---

## Getting Started

### 1. Clone

```bash
git clone https://github.com/2iaad/Inception.git
cd Inception
```

### 2. Create `srcs/.env`

```env
# Domain
DOMAIN_NAME=zderfouf.42.fr

# MariaDB
MYSQL_DB=wordpress
MYSQL_USER=wpuser
MYSQL_PASSWORD=changeme
MYSQL_ROOT_PASSWORD=supersecret

# WordPress admin
WP_TITLE=Inception
WP_ADMIN_N=admin
WP_ADMIN_P=adminpass
WP_ADMIN_E=admin@inception.local

# WordPress second user
WP_U_NAME=editor
WP_U_EMAIL=editor@inception.local
WP_U_PASS=editorpass
WP_U_ROLE=author
```

### 3. Map the domain locally

```bash
echo "127.0.0.1 zderfouf.42.fr" | sudo tee -a /etc/hosts
```

### 4. Build & run

```bash
make build
make up
```

Open **https://zderfouf.42.fr** in a browser. Accept the self-signed certificate — you're in.

---

## Makefile Commands

| Target       | What it does                                                             |
| ------------ | ------------------------------------------------------------------------ |
| `make build` | Creates host volume directories and builds all three images              |
| `make up`    | Starts the stack in detached mode                                        |
| `make down`  | Stops the stack, removes volumes and images                              |
| `make clean` | `docker system prune -af` — wipes **all** unused Docker data on the host |

---

## Environment Variables

| Variable              | Service        | Purpose                          |
| --------------------- | -------------- | -------------------------------- |
| `DOMAIN_NAME`         | WordPress      | Site URL used by `wp core install` |
| `MYSQL_DB`            | MariaDB / WP   | Database name                    |
| `MYSQL_USER`          | MariaDB / WP   | Non-root DB user                 |
| `MYSQL_PASSWORD`      | MariaDB / WP   | Password for the DB user         |
| `MYSQL_ROOT_PASSWORD` | MariaDB        | Root password                    |
| `WP_TITLE`            | WordPress      | Site title                       |
| `WP_ADMIN_N/P/E`      | WordPress      | Admin username / password / email |
| `WP_U_NAME/EMAIL/...` | WordPress      | Second (non-admin) user          |

---

## Services

### NGINX — the only door in

- **Base:** `debian:bookworm`
- **Port:** `443` (TLS 1.2 / 1.3 only)
- **Cert:** self-signed, generated at image build time via `openssl`
- Proxies `*.php` requests to `wordpress:9000` over FastCGI

### WordPress — PHP-FPM, no Apache

- **Base:** `debian:bookworm` + `php8.2-fpm`, `php-mysql`
- Bootstraps the site with **wp-cli**: downloads core, writes `wp-config.php`, installs, creates the admin and a second user
- Listens on `0.0.0.0:9000` for FastCGI
- Idempotent startup — safe to restart

### MariaDB — the store

- **Base:** `debian:bookworm` + `mariadb-server`
- Creates the database, the app user, and grants privileges on first boot
- Runs `mysqld_safe` in the foreground as PID 1
- Healthchecked with `mysqladmin ping` so WordPress waits for it cleanly

---

## Networking & Security

- **Private bridge network** (`inception`) — no container publishes ports except NGINX on `443`.
- **No HTTP.** Port 80 is never opened. NGINX only listens on `443`.
- **Self-signed TLS** with SNI on `zderfouf.42.fr`.
- **Secrets isolation** — credentials are loaded from `.env` at runtime and never baked into layers.
- **Persistent, host-bound volumes** — WordPress files and the MySQL data directory survive `docker compose down` (use `make down` for a full reset).
- **Healthcheck gating** — WordPress waits on `condition: service_healthy` for MariaDB, avoiding race conditions on first boot.

---

## Troubleshooting

<details>
<summary><b>The browser shows a certificate warning</b></summary>

Expected — the cert is self-signed. Click through the warning or import the cert into your trust store.
</details>

<details>
<summary><b><code>make build</code> fails on the <code>mkdir</code> step</b></summary>

The Makefile creates `/home/zderfouf/data/...`. If your Unix login isn't `zderfouf`, change the paths in both the `Makefile` and `srcs/docker-compose.yml`.
</details>

<details>
<summary><b>WordPress can't reach the database</b></summary>

Check the MariaDB logs: `docker logs mariadb`. The most common cause is a stale data volume from a previous run — wipe it with `make down` and rebuild.
</details>

<details>
<summary><b>Port 443 is already in use</b></summary>

Another service (often a local NGINX or Apache) is holding the port. Stop it with `sudo systemctl stop nginx` (or similar) and re-run `make up`.
</details>

<details>
<summary><b>Changes to a Dockerfile aren't applied</b></summary>

Docker is caching. Rebuild without cache: `docker compose -f srcs/docker-compose.yml build --no-cache`.
</details>

---

## Author

[`zderfouf`](https://profile.intra.42.fr/users/zderfouf) at 42 Network

<div align="center">

*Built at 42 · Debian Bookworm · Docker Compose v2*

</div>
