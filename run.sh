#!/bin/bash

PODMAN=$(which podman)
DOCKER=$(which docker)



sudo rm -R ./influxdb2
sudo rm -R ./grafana/var
sudo ./setup_rsyslog.sh
sudo systemctl restart rsyslog.service
if [[ -z "$PODMAN" ]]
then
  sudo ./setup_stack.sh
 else
  ./setup_stack.sh
fi


