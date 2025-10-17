FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y mariadb-server

COPY ./tools/mariadb.sh /

RUN chmod +x /mariadb.sh

ENTRYPOINT ["./mariadb.sh"]