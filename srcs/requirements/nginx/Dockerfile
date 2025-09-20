# pull the base image
FROM debian:12

# update and upgrade the system
RUN apt-get update && apt-get upgrade -y

# install the required packages
RUN apt-get install -y nginx openssl

# create the ssl directory
RUN mkdir -p /etc/nginx/ssl

# generate the ssl certificate
RUN openssl req -x509 -nodes -out /etc/nginx/ssl/inception.crt -keyout \
    /etc/nginx/ssl/inception.key -subj "/C=MO/ST=KH/L=KH/O=42/OU=42/CN=domain_name.fr/UID=admin_name"

# html file to serve as response
RUN mkdir -p /var/www/html && echo "<h1>Salam ana f Engine-x🎉</h1>" > /var/www/html/index.html

# copy the nginx configuration file
COPY ./nginx.conf /etc/nginx/nginx.conf

# define the command to run when the container starts
CMD ["nginx", "-g", "daemon off;"]