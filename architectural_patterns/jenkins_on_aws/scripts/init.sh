#!/bin/bash

echo "Building the container image..."
docker build --no-cache -t jenkins_on_aws ..

echo "Initiating the container..."
docker run -dit -v $(pwd)/../:/app \
  --env-file ../.env \
  --name jenkins_on_aws \
  jenkins_on_aws /bin/bash

