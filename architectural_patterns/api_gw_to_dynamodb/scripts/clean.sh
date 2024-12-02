#!/bin/bash

echo "Cleaning..."

docker exec api_gw_to_dynamodb terraform -chdir=/app destroy -auto-approve

echo "clean.sh completed!"