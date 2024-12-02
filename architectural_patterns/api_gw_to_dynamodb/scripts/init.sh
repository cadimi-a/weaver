#!/bin/bash

# The following line is used for GitHub Actions --------------
container_name="${1:?Error: No container name provided}"

echo "Removing the existing container if it exists..."
docker rm -f ${container_name} 2>/dev/null || true
docker rmi ${container_name} 2>/dev/null || true

echo "Building the container image..."
docker build --no-cache -t ${container_name} ..

echo "Initiating the container..."
docker run -dit -v "$(pwd)/../:/app" \
  --name ${container_name} \
  --env-file ../.env \
  ${container_name} /bin/bash

# ------------------------------------------------------------

echo "Installing python dependencies..."
docker exec ${container_name} pip install -r /app/requirements.txt --break-system-packages

echo "init.sh completed!"