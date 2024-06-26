#!/bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color
set -o allexport
source .env
set +o allexport

printf  "Setting up influxDB bucket ${RED}$DB_NAME${NC} and token\n"
docker compose -f docker-compose.yml down > /dev/null

mkdir -p influxdb2

# Step 1: Run InfluxDB container
docker run -d --replace --name=influxdb_setup \
  -p 8086:8086 \
  -v ./influxdb2:/var/lib/influxdb2 \
  -e INFLUXDB_ADMIN_USER=$DB_USER \
  -e INFLUXDB_ADMIN_PASSWORD=$DB_PASSWORD \
  influxdb:latest

# Wait for InfluxDB to start up
sleep 15

# Step 2: Initialize InfluxDB instance
docker exec influxdb_setup influx setup \
  --username $DB_USER \
  --password $DB_PASSWORD \
  --org $DB_ORG \
  --bucket $DB_NAME \
  --retention $DB_RETENTION \
  --force

# Step 3: Create read-write token
ORG_ID=$(docker exec influxdb_setup influx org list | grep myorg | awk '{print $1}')
# echo "$ORG_ID"
FULLTOKEN=$(docker exec influxdb_setup influx auth create \
  --org-id $ORG_ID \
  --read-buckets \
  --write-buckets | echo "$(sed -n '1!p')" )

ARR=($FULLTOKEN)
TOKEN=${ARR[1]}
printf "Your read-write token is:  ${RED}${TOKEN}${NC}\n"
# echo "Your read-write token is: ${ARR[1]}"

search_text=$(grep -i "DB_TOKEN" ".env")
replace_text="DB_TOKEN=$TOKEN"

sed -i "s|$search_text|$replace_text|g" ".env"

printf "Remove setup instance:  ${RED}influx_setup${NC}\n"

docker rm -f influxdb_setup
printf "Start container stack"

docker compose --env-file .env -f docker-compose.yml up -d