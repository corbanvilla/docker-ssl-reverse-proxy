#!/bin/sh

# How does this work and why is it so complex?
#
# It's to solve a catch-22 issue. The Certbot container needs NGINX configured 
# and handing back requests to verify the server with the Domain
# before the certificate can be issued. However, you can't start
# NGINX with ssl certificates if they haven't been issued yet. 
# This script does the following:
#
# 1. Check if certificates have been issued. 
#      - If yes : start normally
#      - If no  : continue down script
#
# 2. Confirm environmental variables are present to 
#    generate an NGINX conf
#
# 3. Start NGINX (in background)
#
# 4. Check for SSL certificate to be issued (every 5 seconds)
#
# 5. Generate DH parameters with openssl
#
# 6. Generate NGINX configuration from environment variables
#
# 7. Restart NGINX with new configuration

# Is SSL setup already? 
#   - If so, start normally. 
#   - If not, start generic and wait
if [ -d "/etc/letsencrypt/live" ]; then
  # Start in foreground
  nginx -g "daemon off;"

else
  # Make sure all variables are present to generate configurations
  if [ -z ${domains+x} ]; then 
    echo 'No domain found. Make sure you pass a, "domain" variable.'
    exit 1
  fi

  if [ -z ${endpoint_container+x} ]; then 
    echo 'No endpoint container found. Make sure you pass a, "endpoint_container" variable.'
    exit 1
  fi

  if [ -z ${endpoint_container_port+x} ]; then 
    echo 'No endpoint container port found. Make sure you pass a, "endpoint_container_port" variable.'
    exit 1
  fi

  # Remove commas from domains, replace with spaces
  server_names=$(echo $domains | tr ',' ' ')
  # Select leading domain name for certificate path
  main_domain=$(echo $domains | grep -o -P '^[^, ]+')

  # Sometimes the container would not be ready and nginx would fail to start. 
  # This was required. This will start NGINX in the background
  until nginx; do
    echo "System not ready. Retrying..."
    sleep 1
  done

  # While certbot hasn't grabbed the cert, keep checking...
  while [ ! -d "/etc/letsencrypt/live" ]; do
    echo "Waiting for cerbot..."
    sleep 5
  done
  echo "Certificates found!"

  # Generate ssl dhparams
  echo "Generating SSL dhparams"
  /usr/bin/openssl dhparam -out /assets/ssl-dhparams.pem 2048

  # Create NGINX configuration
  echo "Certs found. Creating NGINX configuration"

  # Delete old configuration file
  rm /etc/nginx/conf.d/default.conf

  # Backslashes required to escape $ where it's for nginx
  # because bash would replace it with nothing
  cat <<- EOF > /etc/nginx/conf.d/site-config.conf 
server {
    listen 80;
    listen 443 ssl;

    server_name $server_names;

    # Rewrite URL to use SSL
    if (\$scheme != "https") {
        return 301 https://\$host\$request_uri;
    }

    # Pass back requests to ctfd flask container
    location / {
        proxy_pass http://$endpoint_container:$endpoint_container_port;
    }

    # Pass back to certbot
    location /.well-known/acme-challenge {
        alias /etc/certbot/.well-known/acme-challenge;
        location ~ /.well-known/acme-challenge/(.*) {
            add_header Content-Type application/jose+json;
        }
    }

    ssl_certificate /etc/letsencrypt/live/$main_domain/fullchain.pem; 
    ssl_certificate_key /etc/letsencrypt/live/$main_domain/privkey.pem; 

    include /assets/options-ssl-nginx.conf; 
    ssl_dhparam /assets/ssl-dhparams.pem;
}
EOF

  # Stop nginx
  nginx -s stop

  # Start nginx in foreground
  nginx -g "daemon off;"

fi
