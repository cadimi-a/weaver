#!/bin/bash

echo "Testing..."
docker exec jenkins_on_aws tofu -chdir=/app validate
docker exec jenkins_on_aws tofu -chdir=/app test -test-directory=test

echo "test.sh completed!"