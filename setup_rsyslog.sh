#!/bin/bash
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define the filename, search string, and the multiline text to append
RSYSLOG="/etc/rsyslog.conf"
SEARCH_STRING="Forward everything"

echo -e "Configuring Rsyslog"

# Check if the file exists
if [[ ! -f "$RSYSLOG" ]]; then
  printf "File $RSYSLOG does not exist. ${RED}Installing rsyslog${NC}\n"
  apt-get install rsyslog
  exit 1
fi

printf "enabling udp reception of log data"

search_module=$(grep -i '#module(load=\"imudp\")' "$RSYSLOG")
search_input=$(grep -i '#input(type=\"imudp\" port=\"514\")' "$RSYSLOG")
replace_module='module(load="imudp")'
replace_input='input(type="imudp" port="514")'


sed -i "s|$search_module|$replace_module|g" "$RSYSLOG"
sed -i "s|$search_input|$replace_input|g" "$RSYSLOG"
# Search for the string in the file
if ! grep -q "$SEARCH_STRING" "$RSYSLOG"; then
  echo "Adding forwarding rule to the file."

  # Append the multiline text to the file
  # echo "$APPEND_TEXT" >> "$FILENAME"
  tee -a "$RSYSLOG" > /dev/null <<EOT
# Forward everything
*.*  action(type="omfwd"
       protocol="tcp" target="127.0.0.1" port="1514"
       Template="RSYSLOG_SyslogProtocol23Format"
       TCP_Framing="octet-counted" KeepAlive="on"
       action.resumeRetryCount="-1"
       queue.type="linkedlist" queue.size="50000")
EOT

else
  echo "String found. No changes made to the file."
fi
