#!/bin/bash
echo "### Creating nginx proxy router"
read -p "Enter your source domain FQDN: " domain

read -p "Enter your destination domain FQDN: " destination

read -p "Enter your email for sending ssl information: " email


domains=($domain)
email=$email
data_path="./certbot"
nginx_path="./nginx/conf"
certbot_path="/var/www/certbot"

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

# Create the necessary folders
mkdir -p "$data_path/www"
mkdir -p "$data_path/conf"


echo "### Deleting existing certificates for $domains ..."
rm -rf "$nginx_path/default.conf"
rm -rf "$nginx_path/default-ssl.conf"

mkdir -p "$nginx_path"
cat > "$nginx_path/default.conf" << EOF
server {
    listen 80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
       return 301 https://$destination$request_uri;
    }
}

EOF
echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx

echo "### Deleting existing certificates for $domains ..."
rm -rf "$data_path/conf/live/$domains"
rm -rf "$data_path/conf/archive/$domains"
rm -rf "$data_path/conf/renewal/$domains.conf"

echo "### Requesting Let's Encrypt certificate for $domains ..."
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

email_arg="--email $email"
if [ -z "$email" ]; then
  email_arg="--register-unsafely-without-email"
fi

staging_arg=""
if [ $staging != "0" ]; then
  staging_arg="--staging"
fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w $certbot_path \
    $staging_arg \
    $email_arg \
    $domain_args \
    --agree-tos \
    --force-renewal" certbot

echo "### Stopping nginx ..."
docker-compose down

echo "### Creating Nginx configuration for SSL ..."
mkdir -p "$nginx_path"
cat > "$nginx_path/default.conf" << EOF
server {
    listen 80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$destination$request_uri;
    }
}
server {
    listen 443 default_server ssl http2;
    listen [::]:443 ssl http2;

    server_name $domain;

    ssl_certificate /etc/nginx/ssl/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/$domain/privkey.pem;
    
    location / {
        return 301 https://$destination$request_uri;
    }
}
EOF


echo "### Reloading nginx with new SSL configuration ..."
docker-compose up --force-recreate -d nginx

echo "### SSL setup completed successfully."
