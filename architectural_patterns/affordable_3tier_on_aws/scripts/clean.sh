#!/bin/bash

echo "Cleaning..."

docker exec affordable_3tier_on_aws terraform -chdir=/app destroy -auto-approve

echo "clean.sh completed!"