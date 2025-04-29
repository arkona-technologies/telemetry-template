#!/bin/env bash

set -o allexport
source /etc/default/telegraf
set +o allexport

# Run eAPI command via curl
# NOTE EAPI_PROTOCOL is http|https
response=$(curl -sk -u "$ARISTA_USER:$ARISTA_PASS" \
  -X POST "$EAPI_PROTOCOL://$ARISTA_HOST/command-api" \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "method": "runCmds",
    "params": {
      "version": 1,
      "cmds": ["show interfaces counters rates"],
      "format": "json"
    },
    "id": "1"
  }')

echo "$response" | tr '{},' '\n' | while read -r line; do
  # New interface starts
  if [[ "$line" =~ ^[[:space:]]*\"Ethernet[0-9/]+\"[[:space:]]*:$ ]]; then
    # Output previous interface (if any)
    if [[ -n "$iface" ]]; then
      echo "arista_interface,interface=$iface in_bps=$in_bps,out_bps=$out_bps,in_pps=$in_pps,out_pps=$out_pps"
    fi
    # Capture new interface name
    iface=$(echo "$line" | sed -E 's/^[[:space:]]*"([^"]+)":.*/\1/')
    # Reset counters
    in_bps=0; out_bps=0; in_pps=0; out_pps=0
    continue
  fi

  # Capture metrics
  [[ "$line" == *'"inBpsRate"'* ]]  && in_bps=$(echo "$line" | sed -E 's/.*: *([0-9.]+).*/\1/')
  [[ "$line" == *'"outBpsRate"'* ]] && out_bps=$(echo "$line" | sed -E 's/.*: *([0-9.]+).*/\1/')
  [[ "$line" == *'"inPpsRate"'* ]]  && in_pps=$(echo "$line" | sed -E 's/.*: *([0-9.]+).*/\1/')
  [[ "$line" == *'"outPpsRate"'* ]] && out_pps=$(echo "$line" | sed -E 's/.*: *([0-9.]+).*/\1/')
done

# Output last interface block
if [[ -n "$iface" ]]; then
  echo "arista_interface,interface=$iface in_bps=$in_bps,out_bps=$out_bps,in_pps=$in_pps,out_pps=$out_pps"
fi