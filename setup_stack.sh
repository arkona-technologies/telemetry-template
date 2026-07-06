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
  printf "HOSTNAME=$HOSTNAME" >> ".env"
fi

printf  "${COLOR_LIGHT_BLUE}[InfluxDB]${COLOR_NC} Setting up telemetry strack\n"

$CONTAINER_ENGINE compose down --remove-orphans

./permissions.sh

# Step 1: Generate a secure cryptographic string to act as the primary Read/Write token
# (Equivalent to your old read-write auth create step)
TOKEN="apiv3_$(openssl rand -hex 32)"

cat <<EOF > ./influxdb3/auth/admin-token.json
{
  "token": "$TOKEN",
  "name": "_admin",
  "description": "Admin token for InfluxDB 3"
}
EOF
# Standardize permissions so user 1500 can read it cleanly
sudo chmod 775 ./influxdb3/auth
sudo chmod 600 ./influxdb3/auth/admin-token.json
sudo chown -R 1500:1500 ./influxdb3/auth

# Step 3: Apply the generated token directly to your environment configuration file
search_text=$(grep -i "DB_TOKEN" ".env")
replace_text="DB_TOKEN=$TOKEN"

if [ -n "$search_text" ]; then
  sed -i "s|$search_text|$replace_text|g" ".env"
else
  printf "DB_TOKEN=$TOKEN" >> ".env"
fi

printf "Your InfluxDB 3 read-write token has been generated: ${COLOR_LIGHT_RED}${TOKEN}${COLOR_NC}\n"
printf "Token configuration successfully written to ./influxdb3/auth/permissions.json\n"
printf "Start container stack via docker-compose now.\n"

set -o allexport
source .env
set +o allexport

$CONTAINER_ENGINE compose --env-file .env -f docker-compose.yml up -d --wait

# printf "\n  Execute ${COLOR_WHITE} \"$CONTAINER_ENGINE exec influxdb influxdb3 create database --retention-period $DB_RETENTION $DB_NAME\"\n ${COLOR_NC} to create the database"

printf "\nTrying to create database...$DB_NAME with retention period $DB_RETENTION"
sleep 2

# Attempt counter
max_attempts=4
attempt=1
success=false
while [ $attempt -le $max_attempts ]; do
  printf "\nChecking InfluxDB status (Attempt $attempt of $max_attempts)..."
  running=$($CONTAINER_ENGINE inspect -f '{{.State.Status}}' influxdb 2>/dev/null)
  if [ "$running" = "running" ]; then
    printf "\nInfluxDB container is running. Executing database creation..."
    dbgrep=$($CONTAINER_ENGINE exec influxdb influxdb3 show databases | grep -i $DB_NAME)
    if [ -n "$dbgrep" ]; then
      success=true
      printf "\n    --------------------------------------------------------"
      printf "\n    ${COLOR_LIGHT_GREEN}Database $DB_NAME created succesfully${COLOR_NC}"
      printf "\n    --------------------------------------------------------\n"
      break
    else
      if $CONTAINER_ENGINE exec influxdb influxdb3 create database --retention-period $DB_RETENTION "$DB_NAME"; then
        printf "\n    --------------------------------------------------------"
        printf "\n    ${COLOR_LIGHT_GREEN}Database $DB_NAME created succesfully${COLOR_NC}"
        printf "\n    --------------------------------------------------------\n"
        printf "To see how you can generate additional databases and non-admin tokens, execute:\n ${COLOR_WHITE} \"  docker exec influxdb influxdb3 create --help\"${COLOR_NC}\n"
        success=true
        break
      else
        printf "\n${COLOR_YELLOW}Execution failed. Database might still be initializing.${COLOR_NC}\n"
      fi
    fi
  else
    printf "Container state is: ${running:-stopped/not found}."
  fi
  if [ $attempt -lt $max_attempts ]; then
    printf "Waiting 5 seconds before retrying..."
    sleep 5
  fi
  attempt=$((attempt + 1))
done
if [ "$success" = false ]; then
  printf "\n    --------------------------------------------------------"
  printf "\n    ${COLOR_LIGHT_RED}WARNING${COLOR_NC}: Automatic database provisioning timed out."
  printf "\n    You can manually initialize it later by running:"
  printf "\n    "
  printf "\n      $CONTAINER_ENGINE exec influxdb influxdb3 create database --retention-period $DB_RETENTION $DB_NAME"
  printf "\n    --------------------------------------------------------\n"
fi
