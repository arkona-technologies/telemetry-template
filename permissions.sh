#!/bin/bash

# --- CONFIGURATION ---
ENV_FILE=".env"
GRAFANA_DATA_DIR="./grafana/var"
LOKI_DATA_DIR="./loki/data"

echo "🚀 Starting Pre-flight check for Monitoring Stack..."

# 1. Detect Group IDs for Promtail
ADM_GID=$(getent group adm | cut -d: -f3)
JOURNAL_GID=$(getent group systemd-journal | cut -d: -f3)

# Fallback to default Debian/Ubuntu IDs if not found
ADM_GID=${ADM_GID:-4}
JOURNAL_GID=${JOURNAL_GID:-101}

echo "📍 Detected ADM GID: $ADM_GID"
echo "📍 Detected Journal GID: $JOURNAL_GID"

# 2. Update .env file with GIDs
sed -i "/^ADM_GID=/d" $ENV_FILE 2>/dev/null || touch $ENV_FILE
sed -i "/^JOURNAL_GID=/d" $ENV_FILE
echo "ADM_GID=$ADM_GID" >> $ENV_FILE
echo "JOURNAL_GID=$JOURNAL_GID" >> $ENV_FILE

# 3. Fix permissions for Grafana
echo "🔒 Adjusting Grafana folder permissions..."
mkdir -p $GRAFANA_DATA_DIR
sudo chown -R 472:472 $GRAFANA_DATA_DIR

# 4. Fix permissions for Loki
echo "🔒 Adjusting Loki data permissions..."
mkdir -p $LOKI_DATA_DIR
sudo chown -R 10001:10001 $LOKI_DATA_DIR

# 5. Create persistent positions file for Promtail
touch ./promtail/positions.yaml
sudo chmod 664 ./promtail/positions.yaml
sudo chown :$ADM_GID ./promtail/positions.yaml

# 6. Ensure persistent journald exists
if [ ! -d "/var/log/journal" ]; then
    echo "📂 Creating persistent journal directory..."
    mkdir -p /var/log/journal
    systemd-tmpfiles --create --prefix /var/log/journal
    systemctl restart systemd-journald
fi