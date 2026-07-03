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

printf  "${COLOR_LIGHT_BLUE}[InfluxDB]${COLOR_NC} Setting up influxDB bucket ${COLOR_LIGHT_RED}$DB_NAME${COLOR_NC} and token\n"

$CONTAINER_ENGINE compose -f docker-compose.yml down

./permissions.sh

# Ensure local directories exist
mkdir -p ./influxdb3/data
mkdir -p ./influxdb3/auth

# Step 1: Generate a secure cryptographic string to act as the primary Read/Write token
# (Equivalent to your old read-write auth create step)
TOKEN=$(openssl rand -hex 32)

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

mkdir -p influxdb2
 $CONTAINER_ENGINE rm -f influxdb_setup
# Step 1: Run InfluxDB container
 $CONTAINER_ENGINE run -d --name=influxdb_setup \
  -p 8086:8086 \
  -v ./influxdb2:/var/lib/influxdb2 \
  -e INFLUXDB_ADMIN_USER=$DB_USER \
  -e INFLUXDB_ADMIN_PASSWORD=$DB_PASSWORD \
  docker.io/influxdb:2

# Wait for InfluxDB to start up
sleep 15

# Step 2: Initialize InfluxDB instance
 $CONTAINER_ENGINE exec influxdb_setup influx setup \
  --username $DB_USER \
  --password $DB_PASSWORD \
  --org $DB_ORG \
  --bucket $DB_NAME \
  --retention $DB_RETENTION \
  --force

sleep 5

# Step 3: Create read-write token
ORG_ID=$($CONTAINER_ENGINE exec influxdb_setup influx org list | grep $DB_ORG | awk '{print $1}')
# echo "$ORG_ID"
FULLTOKEN=$($CONTAINER_ENGINE exec influxdb_setup influx auth create \
  --org-id $ORG_ID \
  --read-buckets \
  --write-buckets | echo "$(sed -n '1!p')" )

ARR=($FULLTOKEN)
TOKEN=${ARR[1]}
printf "Your read-write token is:  ${COLOR_LIGHT_RED}${TOKEN}${COLOR_NC}\n"
# echo "Your read-write token is: ${ARR[1]}"

search_text=$(grep -i "DB_TOKEN" ".env")
replace_text="DB_TOKEN=$TOKEN"

sed -i "s|$search_text|$replace_text|g" ".env"

printf "Remove setup instance: influxdb_setup\n"

 $CONTAINER_ENGINE rm -f influxdb_setup 2&>/dev/null
printf "Start container stack\n"

set -o allexport
source .env
set +o allexport

$CONTAINER_ENGINE compose --env-file .env -f docker-compose.yml up -d
