FROM debian:bookworm

RUN apt-get update && apt-get upgrade -y

# install the required packages
RUN apt-get install -y curl php php-fpm php-mysql mariadb-client

COPY ./WpConfig.sh /

RUN  chmod +x WpConfig.sh

ENTRYPOINT ["./WpConfig.sh"]