#!/bin/bash

echo "Cleaning..."
docker exec jenkins_on_aws tofu -chdir=/app destroy -auto-approve

echo "clean.sh completed!"