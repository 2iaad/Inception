# syntax=docker/dockerfile:1

FROM debian:12

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y mariadb-server

COPY ./tools/mariadb.sh /

RUN chmod +x /mariadb.sh

# ENTRYPOINT ["./mariadb.sh"]