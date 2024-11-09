#!/bin/bash

echo "Deploying..."
docker exec jenkins_on_aws tofu -chdir=/app init
docker exec jenkins_on_aws tofu -chdir=/app apply -auto-approve

echo "deploy.sh completed!"