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

check_for_avx2(){
  # Check /proc/cpuinfo for the avx2 flag
  if grep -q -i 'avx2' /proc/cpuinfo; then
      echo "SUCCESS: AVX2 instruction set detected. InfluxDB 3 can run on this system."
      exit 0
  else
      cat << "EOF"
  ERROR: AVX2 instruction set NOT detected!
  InfluxDB 3 requires AVX2 (x86-64-v3) support and will fail with
  'Illegal instruction (core dumped)' without it.

  ====================================================================
                 HOW TO ENABLE AVX2 IN YOUR HYPERVISOR               
  ====================================================================

  • Proxmox VE:
    Go to VM -> Hardware -> Processors -> Change Type to 'host' 
    (or 'x86-64-v3').

  • QEMU / KVM (libvirt):
    Pass '-cpu host' or '-cpu x86-64-v3' in your startup flags.
    In libvirt XML: <cpu mode='host-passthrough'/>

  • VMware ESXi / Workstation:
    Ensure EVC (Enhanced vMotion Compatibility) mode is not masking AVX2.
    Set baseline to Haswell generation or newer, or disable EVC.

  • Hyper-V:
    Ensure host CPU supports AVX2 (Haswell / Excavator or newer) and turn
    OFF Processor Compatibility mode ("Migrate to a physical computer 
    with a different processor version").
  ====================================================================
EOF
      exit 1
  fi
}


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

check_for_avx2
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

