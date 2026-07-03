#!/bin/bash

set -o allexport
source terminal-colors.env
set +o allexport
set -o allexport
source .env
set +o allexport
# TODO optional to install influx bare-metal
CONTAINER_ENGINE=$(which podman||which docker)

if [ -z "$CONTAINER_ENGINE" ]; then
    printf "${COLOR_LIGHT_RED}Error: Neither docker or podman has been found, please install or make sure that it's in your PATH\n"
    exit 1  # Exit with a non-zero status to indicate an error
fi

HOSTNAME=$(hostname)
search_text=$(grep -i "HOSTNAME" ".env")
replace_text="HOSTNAME=$HOSTNAME"

if [ -n "$search_text" ]; then
  sed -i "s|$search_text|$replace_text|g" ".env"
else
  echo "HOSTNAME=$HOSTNAME" >> ".env"
fi

printf  "${COLOR_LIGHT_BLUE}[InfluxDB]${COLOR_NC} Setting up influxDB database ${COLOR_LIGHT_RED}$DB_NAME${COLOR_NC} and token\n"

$CONTAINER_ENGINE compose -f docker-compose.yml down

./permissions.sh

# Step 1: Generate a secure cryptographic string to act as the primary Read/Write token
# (Equivalent to your old read-write auth create step)
TOKEN="apiv3_$(openssl rand -hex 32)"

# Step 2: Write out InfluxDB 3's required tokens JSON permissions format
# This explicitly grants our new token unlimited access to the targeted telemetry database
cat <<EOF > ./influxdb3/auth/tokens.json
[
  {
    "token": "$TOKEN",
    "description": "Telemetry Stack Provisioned token",
    "permissions": [
      {
        "action": "read",
        "resource": "database:$DB_NAME"
      },
      {
        "action": "write",
        "resource": "database:$DB_NAME"
      }
    ]
  }
]
EOF

chmod 600 ./influxdb3/auth/tokens.json

# Step 3: Apply the generated token directly to your environment configuration file
search_text=$(grep -i "DB_TOKEN" ".env")
replace_text="DB_TOKEN=$TOKEN"

if [ -n "$search_text" ]; then
  sed -i "s|$search_text|$replace_text|g" ".env"
else
  echo "DB_TOKEN=$TOKEN" >> ".env"
fi

printf "Your InfluxDB 3 read-write token has been generated: ${COLOR_LIGHT_RED}${TOKEN}${COLOR_NC}\n"
printf "Token configuration successfully written to ./influxdb3/auth/tokens.json\n"
printf "Start container stack via docker-compose now.\n"

set -o allexport
source .env
set +o allexport

$CONTAINER_ENGINE compose --env-file .env -f docker-compose.yml up -d
