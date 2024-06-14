# Nginx Router

---

This is a SSL enable nginx router that you can comtomize to run on a docker container.
SSL is generated using LetsEncrypt.

## Make Executable

### Linux

```sh
sudo chmod +x init-ssl.sh
```

### Initiate the router

```sh
sudo ./init-ssl.sh
```

### Inputs

```
Enter your source domain FQDN: example.com // Domain to enable ssl and accept the traffic to the router
Enter your destination domain FQDN: www.example2.com // Domain with you want to redirect to
Enter your email for sending ssl information: example@email.com //Email to get alert about ssl expiry

```

## Modification to turn into proxy server

Open `init-ssl.sh`

Look for this code

```sh
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
```

### Hosting node app as reverse proxy

Change _location_ to

```sh
location / {
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Host $http_host;
      proxy_set_header X-NginX-Proxy true;

      proxy_pass http://127.0.0.1:3000/; # your host
      proxy_redirect off;
    }
```

### Hosting React Build

```sh

server {
    listen 80;
    server_name $domain;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    root /var/www/html;  # Change this path to the location of your build files
    location / {
        try_files $uri /index.html;
    }
}
server {
    listen 443 default_server ssl http2;
    listen [::]:443 ssl http2;

    server_name $domain;

    ssl_certificate /etc/nginx/ssl/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/$domain/privkey.pem;

    root /var/www/html;  # Change this path to the location of your build files
    location / {
        try_files $uri /index.html;
    }
}



```

## License

See the [LICENSE](LICENSE.md) file for license rights and limitations (MIT).
