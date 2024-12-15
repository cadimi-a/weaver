#!/bin/bash

echo "Deploying..."

docker exec affordable_3tier_on_aws terraform -chdir=/app init
docker exec affordable_3tier_on_aws terraform -chdir=/app apply -auto-approve
docker exec affordable_3tier_on_aws bash -c 'terraform -chdir=/app output > /app/output.txt'

echo "deploy.sh completed!"