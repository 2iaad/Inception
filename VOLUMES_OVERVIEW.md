# Volumes in Inception

How data is stored, shared, and persisted across the three containers.

---

## 1. The big picture

Two named volumes — `mariadb` and `wordpress` — back this stack. Both are
declared `driver: local` with `o: bind`, which means Docker doesn't allocate
its own storage area; it just bind-mounts a directory that already exists on
the host. The host directories are created by the `Makefile` before
`docker compose up` ever runs.

```
        ┌─────────────────────────────── HOST (Linux) ───────────────────────────────┐
        │                                                                            │
        │   /root/data/                                                              │
        │   ├── mariadb/        ◄──── persisted DB files (ibdata, *.ibd, mysql/...)  │
        │   └── wordpress/      ◄──── WP core, wp-config.php, wp-content, uploads    │
        │                                                                            │
        │            ▲                                  ▲                            │
        │            │ bind-mount                       │ bind-mount                 │
        │            │ (Docker local driver, o=bind)    │ (same volume, two mounts)  │
        │            │                                  │                            │
        │   ┌────────┴────────┐         ┌───────────────┴─────────┐                  │
        │   │ volume:         │         │ volume:                 │                  │
        │   │   mariadb       │         │   wordpress             │                  │
        │   └────────┬────────┘         └─────┬─────────────┬─────┘                  │
        │            │                        │             │                        │
        │            ▼                        ▼             ▼                        │
        │   ┌─────────────────┐     ┌─────────────────┐ ┌─────────────────┐          │
        │   │ mariadb         │     │ wordpress       │ │ nginx           │          │
        │   │ container       │     │ container       │ │ container       │          │
        │   │                 │     │                 │ │                 │          │
        │   │ /var/lib/mysql  │     │ /var/www/       │ │ /var/www/       │          │
        │   │                 │     │   wordpress     │ │   wordpress     │          │
        │   └─────────────────┘     └─────────────────┘ └─────────────────┘          │
        │      mysqld writes              php-fpm                nginx               │
        │      DB tables here          reads/writes WP        serves static files    │
        │                              files + writes         (.css, .js, images)    │
        │                              uploads                from same dir          │
        └────────────────────────────────────────────────────────────────────────────┘
```

The `wordpress` volume is mounted into **two** containers at the same path —
that's how NGINX serves the static WordPress assets while PHP-FPM (running
inside the `wordpress` container) executes the `.php` files. They literally
read and write the same directory tree on disk.

---

## 2. Volume declarations (`srcs/docker-compose.yml`)

```yaml
volumes:
  mariadb:
    name: mariadb
    driver: local
    driver_opts:
      device: /root/data/mariadb     # host directory
      o: bind                        # this is a bind mount, not a real volume
      type: none

  wordpress:
    name: wordpress
    driver: local
    driver_opts:
      device: /root/data/wordpress
      o: bind
      type: none
```

What `driver: local` + `o: bind` actually means:

| Field | Meaning |
|-------|---------|
| `driver: local` | Use Docker's built-in local volume driver (no plugin). |
| `type: none` | No filesystem type — don't `mkfs` anything, just expose what's already there. |
| `o: bind` | Mount options. `bind` makes it a bind mount of an existing host path. |
| `device: /root/...` | The host path being bind-mounted. |

The directory **must already exist** on the host before `up` — otherwise Docker
fails. That's why `make build` runs `mkdir -p` first.

---

## 3. Service mounts

```
┌──────────────────────────────────────────────────────────────────────┐
│  service     volume        container path           access pattern   │
├──────────────────────────────────────────────────────────────────────┤
│  mariadb     mariadb   →   /var/lib/mysql           read + write     │
│  wordpress   wordpress →   /var/www/wordpress       read + write     │
│  nginx       wordpress →   /var/www/wordpress       read (static)    │
└──────────────────────────────────────────────────────────────────────┘
```

Notice `nginx` and `wordpress` share the same volume. NGINX never writes —
it just needs the files on disk so it can serve them directly (anything
non-`.php`), while requests for `.php` get proxied over FastCGI to
`wordpress:9000`.

---

## 4. Lifecycle: from `make up` to data on disk

```
make up
  │
  ├── make build
  │     ├── mkdir -p /root/data/wordpress         (host dirs MUST exist
  │     ├── mkdir -p /root/data/mariadb            before compose runs)
  │     └── docker compose build                  (builds 3 images)
  │
  └── docker compose up -d
        │
        ├── docker creates volumes (or reuses existing)
        │   ├── volume "mariadb"  ──► bind-mounts /root/data/mariadb
        │   └── volume "wordpress" ─► bind-mounts /root/data/wordpress
        │
        ├── mariadb container starts
        │   /var/lib/mysql now points at /root/data/mariadb
        │   ├── first run:  mysqld initialises an empty datadir here
        │   │               mariadb.sh creates DB + user + grants
        │   └── later runs: mysqld finds existing files, skips init
        │
        ├── wordpress container starts (after mariadb is healthy)
        │   /var/www/wordpress points at /root/data/wordpress
        │   ├── first run:  wp-config.sh sees no wp-config.php
        │   │               → wp core download / config / install
        │   │               → writes WP files into the volume
        │   └── later runs: wp-config.php already exists → skip install
        │
        └── nginx container starts
            /var/www/wordpress points at /root/data/wordpress
            (same files wordpress just populated — nothing to do)
```

The "if not exists" guards in both entrypoint scripts are what make these
volumes safe to restart: the second `docker compose up` does **not** wipe
your WordPress install.

`wp-config.sh:9`:
```bash
if [ ! -f "wp-config.php" ]; then
    wp core download --allow-root
    ...
fi
```

---

## 5. Persistence guarantees

| Action                      | `/root/data/*` on host | Containers | Images | Docker volumes |
|-----------------------------|------------------------|------------|--------|----------------|
| `docker compose restart`    | kept                   | restarted  | kept   | kept           |
| `make down` (`down -v --rmi all`) | **kept**         | removed    | removed| removed (refs) |
| `make clean`                | **kept**               | removed    | removed| removed        |
| `make fclean`               | **deleted** (`rm -rf`) | removed    | removed| removed        |
| `make re`                   | **kept** (only `clean`, not `fclean`) | rebuilt    | rebuilt| rebuilt        |

The important nuance: `make down` does `docker compose down -v`, which removes
the *Docker volume references*. But because these volumes are bind mounts to
`/root/data/...`, the actual data on disk is **untouched** — Docker only
forgets the volume's name, the host directory still holds every byte. Only
`make fclean` (which runs `rm -rf /root/data`) actually deletes data.

```
   make down  ─►  docker forgets the volume name,
                  but /root/data/* is still there  ──►  next `make up` finds the data

   make fclean ─►  docker forgets the volume name
              ─►  rm -rf /root/data                ──►  next `make up` is a fresh install
```

---

## 6. Quick reference

```
─────────────────────────────────────────────────────────────────────
 Host path                 Volume name   Mounted in              Mode
─────────────────────────────────────────────────────────────────────
 /root/data/mariadb    →   mariadb   →   mariadb:/var/lib/mysql  rw
 /root/data/wordpress  →   wordpress →   wordpress:/var/www/...  rw
 /root/data/wordpress  →   wordpress →   nginx:/var/www/...      rw*
─────────────────────────────────────────────────────────────────────
 * NGINX has rw access, but nginx.conf only ever reads.
```

Source files involved:

- `srcs/docker-compose.yml:5-19`  — volume definitions
- `srcs/docker-compose.yml:26-27` — mariadb mount
- `srcs/docker-compose.yml:47-48` — wordpress mount
- `srcs/docker-compose.yml:61-62` — nginx mount (same volume)
- `Makefile:11-14`                 — `mkdir -p` of host dirs before build
- `Makefile:19-21`                 — `fclean` wipes `/root/data`
