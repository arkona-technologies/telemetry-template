#!/usr/bin/env bash
source .env 2>/dev/null || true

# Configuration settings
HOST="http://localhost:8086"
ORG=${DB_ORG:-"arkona"}
TOKEN=${DB_TOKEN:-"TOKEN"}
BUCKET=${DB_NAME:-"bladerunner"}
OUTPUT_FILE=${FILENAME:-"./export.csv"}
FILTER_EXPR="${RAW_FILTER:-true}"

# Escape quotes
FILTER_EXPR="${FILTER_EXPR//\\/\\\\}"
FILTER_EXPR="${FILTER_EXPR//\"/\\\"}"

# Clear out old outputs
rm -f "$OUTPUT_FILE"
rm -f ./temp_slice.csv

# Step window size (seconds)
STEP_SECONDS=${STEPS:-60}

# Helper: Convert date string or epoch to Unix timestamp (seconds)
to_epoch() {
  local val="$1"
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    echo "$val"
  else
    date -u -d "$val" +%s
  fi
}

# --- Resolve Start & Stop Timestamps ---
# Defaults: Stop = now, Start = 2 hours ago
DEFAULT_STOP=$(date -u +%s)
DEFAULT_START=$((DEFAULT_STOP - 7200))

START_TIMESTAMP=$(to_epoch "${START_DATE:-$DEFAULT_START}")
END_TIMESTAMP=$(to_epoch "${STOP_DATE:-$DEFAULT_STOP}")

echo "Anchor Time (Fixed Present): $(date -u -d @"$END_TIMESTAMP" +'%Y-%m-%dT%H:%M:%SZ')"
echo "Beginning fixed chronological window export..."

CURRENT_START=$START_TIMESTAMP

# Always quote variables in test brackets to prevent "unary operator expected"
while [ "$CURRENT_START" -lt "$END_TIMESTAMP" ]; do
  CURRENT_STOP=$((CURRENT_START + STEP_SECONDS))

  # Ensure we don't query past our fixed end anchor
  if [ "$CURRENT_STOP" -gt "$END_TIMESTAMP" ]; then
    CURRENT_STOP=$END_TIMESTAMP
  fi

  # Convert unix epoch integers to absolute ISO/RFC3339 strings for Flux
  ISO_START=$(date -u -d @"$CURRENT_START" +'%Y-%m-%dT%H:%M:%SZ')
  ISO_STOP=$(date -u -d @"$CURRENT_STOP" +'%Y-%m-%dT%H:%M:%SZ')

  echo "Querying: ${ISO_START} to ${ISO_STOP}"
  Execute query
  influx query \
    --host "$HOST" \
    --org "$ORG" \
    --token "$TOKEN" \
    --raw \
    "from(bucket: \"$BUCKET\") 
       |> range(start: ${ISO_START}, stop: ${ISO_STOP})
       |> filter(fn: (r) => ${FILTER_EXPR})" > ./temp_slice.csv

  QUERY_STATUS=$?

  if [ $QUERY_STATUS -eq 0 ] && [ -f ./temp_slice.csv ]; then
    # If the slice returned rows beyond basic CSV headers, append it
    if [ "$(wc -l < ./temp_slice.csv)" -gt 4 ]; then
      cat ./temp_slice.csv >> "$OUTPUT_FILE"
    fi
    # Advance to the next block only on SUCCESS
    CURRENT_START=$CURRENT_STOP
  else
    echo "⚠️ Query crashed or EOF hit for window ${ISO_START}. Retrying this specific window in 3 seconds..."
    sleep 3
  fi

  sleep 0.2
done

rm -f ./temp_slice.csv
echo "Export complete! Consolidated data saved cleanly to: $OUTPUT_FILE"