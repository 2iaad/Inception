FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y curl php php-fpm php-mysql mariadb-client

COPY ./WpConfig.sh /

RUN  chmod +x WpConfig.sh

ENTRYPOINT ["./WpConfig.sh"]