#!/bin/bash

PODMAN=$(which podman)
DOCKER=$(which docker)

ensure_linger(){
  LINGER_STATUS=$(loginctl show-user $(logname) | grep -i 'linger' | sed 's/Linger=//g')
  echo $LINGER_STATUS
  if [[ "$LINGER_STATUS" == "no" ]]
  then
    printf "Setting [loginctl enable-linger $(logname)] is set\n"
    sudo loginctl enable-linger $(logname)
  fi
}

ensure_docker_group(){
  printf "${BLUE}[Preparation]${ENDCOLOR} Ensure group docker exists\n"
  if [ ! $(getent group docker) ]; then
    printf "${BLUE}[Preparation]${ENDCOLOR} docker group doesn't exist; creating\n"
    sudo groupadd docker
  fi
  if ! id -nG "$(logname)" | grep -qw "docker"; then
    echo $(logname) does not belong to "docker"
    sudo usermod -aG docker "$(logname)"
    printf "${BLUE}[GROUPS]${ENDCOLOR} Re-Starting Script with docker group membership\n"
    exec sg "docker" "$0 $*"
    exit
  fi

}

sudo rm -R ./influxdb2
sudo rm -R ./grafana/var
sudo ./setup_rsyslog.sh
sudo systemctl restart rsyslog.service
ensure_linger
if [[ -z "$PODMAN" ]]
  then
  ensure_docker_group
  ./setup_stack.sh
 else
  ./setup_stack.sh
fi


