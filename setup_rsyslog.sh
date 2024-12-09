#!/bin/bash
set -o allexport
source terminal-colors.env
set +o allexport

# Define the filename, search string, and the multiline text to append
RSYSLOG="/etc/rsyslog.conf"
SEARCH_STRING="Forward everything"

printf "${COLOR_LIGHT_BLUE}Setup Rsyslog\n"

# Check if the file exists
if [[ ! -f "$RSYSLOG" ]]; then
  printf "${COLOR_LIGHT_BLUE}[Rsyslog]${COLOR_NC} File $RSYSLOG does not exist. Installing rsyslog\n"
  apt-get install rsyslog
  exit 1
fi

printf "${COLOR_LIGHT_BLUE}[Rsyslog]${COLOR_NC} Enabling udp reception of log data\n"

search_module=$(grep -i '#module(load=\"imudp\")' "$RSYSLOG")
search_input=$(grep -i '#input(type=\"imudp\" port=\"514\")' "$RSYSLOG")
replace_module='module(load="imudp")'
replace_input='input(type="imudp" port="514")'


sed -i "s|$search_module|$replace_module|g" "$RSYSLOG" >/dev/null
sed -i "s|$search_input|$replace_input|g" "$RSYSLOG" >/dev/null
# Search for the string in the file
if ! grep -q "$SEARCH_STRING" "$RSYSLOG"; then
  printf "${COLOR_LIGHT_BLUE}[Rsyslog]${COLOR_NC} Adding forwarding rule to rsyslog config.\n"

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
  printf "${COLOR_LIGHT_BLUE}[Rsyslog]${COLOR_NC} String found. No changes made to rsyslog config.\n"
fi

printf "${COLOR_LIGHT_BLUE}[Rsyslog]${COLOR_NC} Re/starting rsyslog\n"
systemctl restart rsyslog.service > /dev/null
printf "${COLOR_LIGHT_BLUE}[Rsyslog]${COLOR_NC} Rsyslog setup complete\n\n"