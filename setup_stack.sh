#!/bin/bash

set -o allexport
source terminal-colors.env
set +o allexport
set -o allexport
source .env
set +o allexport

CONTAINER_ENGINE=$(which podman||which docker)

if [ -z "$CONTAINER_ENGINE" ]; then
    printf "${COLOR_RED}Error: Neither docker or podman has been found, please install or make sure that it's in your PATH\n"
    exit 1  # Exit with a non-zero status to indicate an error
fi

printf  "${COLOR_LIGHT_BLUE}[InfluxDB]${COLOR_NC} Setting up influxDB bucket ${COLOR_LIGHT_RED}$DB_NAME${COLOR_NC} and token\n"
if hash docker-compose 2>/dev/null
then
    docker-compose -f docker-compose.yml down
else
    $CONTAINER_ENGINE compose -f docker-compose.yml down
fi

mkdir -p influxdb2
$CONTAINER_ENGINE rm -f influxdb_setup
# Step 1: Run InfluxDB container
$CONTAINER_ENGINE run -d --name=influxdb_setup \
  -p 8086:8086 \
  -v ./influxdb2:/var/lib/influxdb2 \
  -e INFLUXDB_ADMIN_USER=$DB_USER \
  -e INFLUXDB_ADMIN_PASSWORD=$DB_PASSWORD \
  influxdb:latest

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
printf "Your read-write token is:  ${COLOR_RED}${TOKEN}${COLOR_NC}\n"
# echo "Your read-write token is: ${ARR[1]}"

search_text=$(grep -i "DB_TOKEN" ".env")
replace_text="DB_TOKEN=$TOKEN"

sed -i "s|$search_text|$replace_text|g" ".env"

printf "Remove setup instance: influxdb_setup\n"

$CONTAINER_ENGINE rm -f influxdb_setup
printf "Start container stack"

set -o allexport
source .env
set +o allexport

if hash docker-compose 2>/dev/null
then
    docker-compose --env-file .env -f docker-compose.yml up -d
else
    $CONTAINER_ENGINE compose --env-file .env -f docker-compose.yml up -d
fi
