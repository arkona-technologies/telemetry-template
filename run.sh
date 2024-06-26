#!/bin/bash

sudo rm -R ./influxdb2
sudo rm -R ./grafana/var
sudo ./setup_rsyslog.sh
sudo systemctl restart rsyslog.service
./setup_stack.sh