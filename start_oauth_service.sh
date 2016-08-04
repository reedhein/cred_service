docker kill oauth_server
docker rm oauth_server
docker build -t oauth_server ./
docker run -d \
  -p 4567:4567 \
  --name oauth_server \
  -v db_share:/opt/cred_service/data \
  oauth_server
