# syntax=docker/dockerfile:1
FROM debian:12

RUN apt-get update && apt-get upgrade -y

RUN apt-get install -y nginx openssl

RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -noenc \
    -out /etc/nginx/ssl/inception.crt \
    -keyout /etc/nginx/ssl/inception.key -subj "/C=MA/CN=localhost"

COPY ./nginx.conf /etc/nginx/nginx.conf

# define the command to run when the container starts
CMD ["nginx", "-g", "daemon off;"]