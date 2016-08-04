docker kill lets-nginx
docker rm lets-nginx
docker run --detach \
  --name lets-nginx \
  --link oauth_server:oauth_server \
  --env EMAIL=doug@reedhein.com \
  --env DOMAIN=teamkatlas.com \
  --env UPSTREAM=oauth_server:4567 \
  --publish 80:80 \
  --publish 443:443 \
  smashwilson/lets-nginx
