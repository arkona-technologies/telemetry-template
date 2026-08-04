#!/bin/bash

# Configuration settings
HOST="http://localhost:8086"
ORG="arkona"
TOKEN="$TOKEN"
BUCKET="bladerunner"
OUTPUT_FILE="./export_last_3_days.csv"
# Clear out old outputs
rm -f "$OUTPUT_FILE"
rm -f ./temp_slice.csv

# 1. Establish a rigid, FIXED anchor time for "now" (UTC)
NOW_TIMESTAMP=$(date -u +%s)

# Calculate the static start time (3 days ago = 259200 seconds)
START_TIMESTAMP=$((NOW_TIMESTAMP - 259200))
END_TIMESTAMP=$NOW_TIMESTAMP

# Step window size (10 minutes = 600 seconds)
STEP_SECONDS=600

echo "Anchor Time (Fixed Present): $(date -u -d @$NOW_TIMESTAMP +'%Y-%m-%dT%H:%M:%SZ')"
echo "Beginning fixed chronological window export..."

CURRENT_START=$START_TIMESTAMP

while [ $CURRENT_START -lt $END_TIMESTAMP ]; do
  CURRENT_STOP=$((CURRENT_START + STEP_SECONDS))
  
  # Ensure we don't accidentally query past our fixed end anchor
  if [ $CURRENT_STOP -gt $END_TIMESTAMP ]; then
    CURRENT_STOP=$END_TIMESTAMP
  fi

  # Convert unix epoch integers to absolute ISO/RFC3339 strings for Flux
  ISO_START=$(date -u -d @$CURRENT_START +'%Y-%m-%dT%H:%M:%SZ')
  ISO_STOP=$(date -u -d @$CURRENT_STOP +'%Y-%m-%dT%H:%M:%SZ')

  echo "Querying: ${ISO_START} to ${ISO_STOP}"

  # 2. Execute query. Timeout is defined INSIDE the Flux query engine context.
  influx query \
    --host "$HOST" \
    --org "$ORG" \
    --token "$TOKEN" \
    --raw \
    "from(bucket: \"$BUCKET\") 
       |> range(start: ${ISO_START}, stop: ${ISO_STOP})" > ./temp_slice.csv

  QUERY_STATUS=$?

  if [ $QUERY_STATUS -eq 0 ] && [ -f ./temp_slice.csv ]; then
    # If the slice returned rows beyond just the basic CSV headers, append it
    if [ $(wc -l < ./temp_slice.csv) -gt 4 ]; then
      cat ./temp_slice.csv >> "$OUTPUT_FILE"
    fi
    # Advance to the next block only on SUCCESS
    CURRENT_START=$CURRENT_STOP
  else
    echo "⚠️ Query crashed or EOF hit for window ${ISO_START}. Retrying this specific window in 3 seconds..."
    sleep 3
    # Note: CURRENT_START is not incremented here, causing a clean loop retry on the same block
  fi

  # Gentle breathing room for the InfluxDB engine garbage collector
  sleep 0.2
done

rm -f ./temp_slice.csv
echo "Export complete! Consolidated data saved cleanly to: $OUTPUT_FILE"