#!/bin/bash
set -o allexport
source terminal-colors.env
set +o allexport
PODMAN=$(which podman)
DOCKER=$(which docker)
NO_SYSLOG=$1
CONTAINER_ENGINE=$(which podman||which docker)
if [[ -z "$PODMAN" && -z "$DOCKER" ]]; then
  printf "${COLOR_LIGHT_RED}Neither docker or podman have been found, you can install it with the wizard:\n${COLOR_LIGHT_GRAY}Select 'Check/Install docker' or 'Check/Install podman' to install one of them if not found"
  exit 1
fi

ensure_linger(){
  LINGER_STATUS=$(loginctl show-user $(logname) | grep -i 'linger' | sed 's/Linger=//g')
  if [[ "$LINGER_STATUS" == "no" ]]
  then
    printf "${COLOR_LIGHT_BLUE}Setting [loginctl enable-linger $(logname)]\n"
    sudo loginctl enable-linger $(logname)
  fi
}

ensure_docker_group(){
  printf "${COLOR_LIGHT_BLUE}[Preparation]${COLOR_NC} Ensure group docker exists\n"
  if [ ! $(getent group docker) ]; then
    printf "${COLOR_LIGHT_BLUE}[Preparation]${COLOR_NC} docker group doesn't exist; creating\n"
    sudo groupadd docker
  fi
  if ! id -nG "$(logname)" | grep -qw "docker"; then
    echo $(logname) does not belong to "docker"
    sudo usermod -aG docker "$(logname)"
    newgrp docker
    printf "${COLOR_LIGHT_BLUE}[GROUPS]${COLOR_NC} Re-Starting Script with docker group membership\n"
    exec sg "docker" "$0 $*"
    exit
  fi

}

remove_directories(){
  printf "${COLOR_GRAY}Stopping containers\nRemove local directories\n  - ./grafana/var\n  - ./influxdb3\n"
  $CONTAINER_ENGINE compose down --remove-orphans
  sudo rm -R ./influxdb3 > /dev/null
  sudo rm -R ./grafana/var > /dev/null
}


remove_directories

if [[ -z "$NO_SYSLOG" ]]
  then
    sudo ./setup_rsyslog.sh
  else
    printf "${COLOR_LIGHT_GRAY}Skipping rsyslog installation, loki won't work without manual setup\n"
fi

ensure_linger

if [[ -z "$PODMAN" ]]
  then
  ensure_docker_group
  ./setup_stack.sh
 else
  ./setup_stack.sh
fi


