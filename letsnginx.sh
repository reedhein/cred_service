docker run --detach \
  --name lets-nginx \
  --env EMAIL=doug@reedhein.com \
  --env DOMAIN=zombiegestation.com \
  --env UPSTREAM=oauth_server:4567 \
  --publish 80:80 \
  --publish 443:443 \
  smashwilson/lets-nginx
