#!/bin/bash

# Check if certs have already been generated
if [ ! -d "/etc/letsencrypt/live" ]; then
  
  # Confirm all requirements 
  echo "No certs found! Testing requirements..."
  if [ -z ${email+x} ]; then 
    echo "No email found. Make sure you're passing a, 'email' variable'"
    exit 1
  fi
  echo "Using email: $email"
  
  if [ -z ${domains+x} ]; then 
    echo "No domain found. Make sure you're passing a, 'domain' variable'"
    exit 1
  fi
  echo "Using domain(s): $domains"

  if [ -z ${staging+x} ]; then
    echo "No staging parameter found. Make sure you're passing a, 'staging' parameter (true of false)"
    exit 1
  fi
  echo "Staging is set to: $staging"

  #if staging is set to true, add --staging to certbot command. Otherwise add nothing
  if [ "$staging" = true ]; then
    staging_parameter="--staging"
  else
    staging_parameter=""
  fi

  # Certbot command to call (add --staging to end for testing) 
  call_certbot="certbot certonly --webroot -w /usr/share/nginx/html/ --quiet --noninteractive --agree-tos --email=$email $staging_parameters"

  # Test if multiple domains have been requested (if they have, they will be separated by commas)
  if [ $domains != *","* ]; then
    # Call certbot, use domains variable
    echo "Requesting cert for: $domains"
    until $call_certbot -d $domains; do
      echo "Retrying..."
      sleep 2
    done
  else
    IFS=',' read -ra addr <<< "$domains"
    for domain in "${addr[@]}"; do
      echo "Requesting cert for: $domain"
      until $call_certbot -d $domain; do
        echo "Retrying..."
        sleep 2
      done
    done 
  fi

# Else /etc/letsencrypt/live already exists, certs have already been generated
else
  # Attempt certificate renewal
  echo "We found your existing certificates. Attempting renewal!"
  certbot renew
fi

# Start cron job
echo "Beginning cron job"
crond -f -L -
