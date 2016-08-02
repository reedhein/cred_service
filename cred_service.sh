docker kill oauth_server
docker rm oauth_server
docker build -t oauth_server ./
docker run  \
  --name oauth_server \
  oauth_server
