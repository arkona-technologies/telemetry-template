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
  echo "DB_TOKEN=$TOKEN" >> ".env"
fi

printf "Your InfluxDB 3 read-write token has been generated: ${COLOR_LIGHT_RED}${TOKEN}${COLOR_NC}\n"
printf "Token configuration successfully written to ./influxdb3/auth/permissions.json\n"
printf "To see, how you can generate additional non-admin tokens, execute:\n \"docker exec -it <influxdb-container> influxdb3 create token --help\"\n"
printf "Start container stack via docker-compose now.\n"

set -o allexport
source .env
set +o allexport

$CONTAINER_ENGINE compose --env-file .env -f docker-compose.yml up -d

# Attempt counter
max_attempts=4
attempt=1
success=false

while [ $attempt -le $max_attempts ]; do
  echo "Checking InfluxDB status (Attempt $attempt of $max_attempts)..."
  running=$($CONTAINER_ENGINE inspect -f '{{.State.Status}}' influxdb 2>/dev/null)

  if [ "$running" = "running" ]; then
    echo "InfluxDB container is running. Executing database creation..."

    if $CONTAINER_ENGINE exec influxdb influxdb3 create database --retention-period "$DB_RETENTION" "$DB_NAME"; then
      success=true
      break
    else
      echo "Execution failed. Database might still be initializing."
    fi
  else
    echo "Container state is: ${running:-stopped/not found}."
  fi

  if [ $attempt -lt $max_attempts ]; then
    echo "Waiting 5 seconds before retrying..."
    sleep 5
  fi
  attempt=$((attempt + 1))
done


if [ "$success" = false ]; then
  echo "--------------------------------------------------------"
  echo "WARNING: Automatic database provisioning timed out."
  echo "You can manually initialize it later by running:"
  echo ""
  echo "  $CONTAINER_ENGINE exec influxdb influxdb3 create database --retention-period $DB_RETENTION $DB_NAME"
  echo "--------------------------------------------------------"
fi