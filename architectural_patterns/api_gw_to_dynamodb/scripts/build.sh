#!/bin/bash

# The following line is used for GitHub Actions --------------

container_name="${1:?Error: No container name provided}"
optional_param="${2}"

if [[ "${optional_param}" == "actions" ]]; then
  echo "Initiating the container..."
  docker run -dit -v "$(pwd)/../:/app" \
    --name ${container_name} \
    ${container_name} /bin/bash
else
  echo "Skipping container initiation as no 'actions' parameter was provided."
fi
# ------------------------------------------------------------

# No build required for this architecture

echo "build.sh completed!"