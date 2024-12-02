#!/bin/bash

echo "Deploying..."

docker exec api_gw_to_dynamodb terraform -chdir=/app init
docker exec api_gw_to_dynamodb terraform -chdir=/app apply -auto-approve
docker exec api_gw_to_dynamodb bash -c 'terraform -chdir=/app output > /app/output.txt'

echo "deploy.sh completed!"