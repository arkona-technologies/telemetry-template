#!/bin/env bash
set -o allexport
source ../.env
set +o allexport
# --- Configuration Settings ---
CONTAINER_NAME="${DB_CONTAINER_NAME:-influxdb}"       # Name of your running InfluxDB 3 container
DATABASE="${DB_NAME:-bladerunner}"                    # InfluxDB 3 database name
TOKEN="$DB_TOKEN"                                     # Admin or READ token
HOST_URL="http://localhost:${DB_PORT:-8181}"          # Default HTTP API port for InfluxDB 3
OUTPUT_FILE=${OUTPUT_FILE:-./export.csv}
TEMP_FILE="./temp_slice.csv"
DURATION=${DURATION_S:-259200}
STEP_DURATION=${STEP_DURATION_S:-600}
# Clear old files on host
rm -f "$OUTPUT_FILE" "$TEMP_FILE"

# 1. Establish a rigid, FIXED anchor time for "now" (UTC)
NOW_TIMESTAMP=$(date -u +%s)

# Calculate the static start time (3 days ago = 86400 seconds)
START_TIMESTAMP=$((NOW_TIMESTAMP - ${DURATION:-}))
END_TIMESTAMP=$NOW_TIMESTAMP

# Step window size (10 minutes = 600 seconds)
STEP_SECONDS=600

echo "Anchor Time (Fixed Present): $(date -u -d @$NOW_TIMESTAMP +'%Y-%m-%dT%H:%M:%SZ')"
echo "Beginning fixed chronological window export from InfluxDB 3..."

CURRENT_START=$START_TIMESTAMP
IS_FIRST_SLICE=true

while [ $CURRENT_START -lt $END_TIMESTAMP ]; do
  CURRENT_STOP=$((CURRENT_START + STEP_SECONDS))
  
  # Ensure we don't query past our fixed end anchor
  if [ $CURRENT_STOP -gt $END_TIMESTAMP ]; then
    CURRENT_STOP=$END_TIMESTAMP
  fi

  # Convert unix epoch integers to ISO 8601 strings for SQL
  ISO_START=$(date -u -d @$CURRENT_START +'%Y-%m-%dT%H:%M:%SZ')
  ISO_STOP=$(date -u -d @$CURRENT_STOP +'%Y-%m-%dT%H:%M:%SZ')

  echo "Querying SQL window: ${ISO_START} to ${ISO_STOP}"

  # Construct SQL query (Extracts all data in window across all measurements)
  SQL_QUERY="SELECT * FROM $DATABASE WHERE time >= '$ISO_START' AND time < '$ISO_STOP'"

  # 2. Execute influx3 query inside container and stream output directly to host file
  docker exec -i "$CONTAINER_NAME" influx3 query \
    --host "$HOST_URL" \
    --database "$DATABASE" \
    --token "$TOKEN" \
    --format csv \
    "$SQL_QUERY" > "$TEMP_FILE" 2>/dev/null

  QUERY_STATUS=$?

  if [ $QUERY_STATUS -eq 0 ] && [ -s "$TEMP_FILE" ]; then
    # Check if slice returned actual data beyond just the header line
    LINE_COUNT=$(wc -l < "$TEMP_FILE")

    if [ "$LINE_COUNT" -gt 1 ]; then
      if [ "$IS_FIRST_SLICE" = true ]; then
        # For the first chunk, write headers and data
        cat "$TEMP_FILE" >> "$OUTPUT_FILE"
        IS_FIRST_SLICE=false
      else
        # For subsequent chunks, strip the 1-line CSV header to prevent duplicate headers
        tail -n +2 "$TEMP_FILE" >> "$OUTPUT_FILE"
      fi
    fi

    # Advance loop only on SUCCESS
    CURRENT_START=$CURRENT_STOP
  else
    echo "⚠️ Query failed or returned empty for window ${ISO_START}. Retrying in 3 seconds..."
    sleep 3
  fi

  # Gentle breathing room
  sleep 0.2
done

rm -f "$TEMP_FILE"
echo "Export complete! Consolidated CSV saved directly to host at: $OUTPUT_FILE"