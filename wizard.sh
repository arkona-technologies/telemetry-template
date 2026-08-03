#!/bin/bash
export NEWT_COLORS='
  window=black,black
  border=brightblue,black
  title=brightblue,black
  textbox=gray,black
  listbox=white,black
  sellistbox=black,green
  actsellistbox=black,green
  actlistbox=black,white
  button=black,green
  actbutton=white,lightblue
  root=black,black
'
HOST=$(hostname)
EDITOR=
WIZARD=
OS=$(. /etc/os-release && echo "${ID}")
TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
TOTAL_RAM_GIB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print kb / 1048576 }')
PODMAN=$(type podman)
DOCKER=$(type docker)
check_for_whiptail() {
  if ! command -v whiptail 2>&1 >/dev/null
  then
    echo "<the_command> could not be found, trying to install"
    if command -v apt 2>&1 >/dev/null
    then
      sudo apt install whiptail
    elif command -v dnf 2>&1 >/dev/null
    then
      sudo dnf install newt
    elif command -v yum 2>&1 >/dev/null
    then
      sudo yum install newt
    else
      printf "install package whiptail (ubuntu/debian) or newt to use the wizard installer\n"
      exit 1
    fi
  fi
  WIZARD=$(which whiptail||which newt)
}
install_podman_compose(){
  if ! command -v pip3 2>&1 >/dev/null
  then
    echo "pip3 could not be found, trying to install"
    if command -v apt 2>&1 >/dev/null
    then
      sudo apt install python3-pip
    elif command -v dnf 2>&1 >/dev/null
    then
      sudo dnf install python3-pip
    else
      printf "install package python3-pip and execute `pip3 install podman-compose` to use podman with compose\n"
      exit 1
    fi
  fi
}
check_for_podman() {
  if ! command -v podman 2>&1 >/dev/null
  then
    CHOICE=$($WIZARD --title "Install podman" --menu "To use podman, you have to install podman and podman-compose\nThis wizard can install it for you, but without guaranteed success. For more information, please refer to:\n - https://podman.io/docs/installation\n - https://github.com/containers/podman-compose\nPress 'y' to continue\n" 20 60 4 \
    "y" "Install podman" \
    "n" "Back" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $CHOICE in
          "y")
            if command -v apt 2>&1 >/dev/null
            then
              sudo apt install podman
              install_podman_compose
            elif command -v dnf 2>&1 >/dev/null
            then
              sudo dnf install podman
              install_podman_compose
            elif command -v yum 2>&1 >/dev/null
            then
              sudo yum install podman
              install_podman_compose
            else
              printf "install package podman to use the wizard installer\n"
              exit 1
            fi
            ;;
          *)
            main
            ;;
        esac
    else
        echo "You canceled."
    fi
  else
   printf "podman found\n"
  fi
}
check_for_docker() {
  if ! command -v docker 2>&1 >/dev/null
  then
    CHOICE=$($WIZARD --title "Install docker" --menu "No docker installation found.\nThis wizard can install it for you, but without guaranteed success. For more information, please refer to:\n - https://docs.docker.com/engine/install/\nPress 'y' to continue\n" 20 60 4 \
    "y" "Install docker" \
    "n" "Back" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $CHOICE in
          "y")
            if command -v apt 2>&1 >/dev/null
            then
              for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
              # Add Docker's official GPG key:
              sudo apt update
              sudo apt install ca-certificates curl
              sudo install -m 0755 -d /etc/apt/keyrings
              if [ $OS = "debian" ];then
                sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
                sudo chmod a+r /etc/apt/keyrings/docker.asc
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
                  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              else
                sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
                sudo chmod a+r /etc/apt/keyrings/docker.asc

                # Add the repository to Apt sources:
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
                  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              fi
              
              sudo apt update
              sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              sudo groupadd docker
              sudo usermod -aG docker $USER
              sudo systemctl enable --now docker
            elif command -v dnf 2>&1 >/dev/null
            then
              sudo dnf remove docker \
                          docker-client \
                          docker-client-latest \
                          docker-common \
                          docker-latest \
                          docker-latest-logrotate \
                          docker-logrotate \
                          docker-selinux \
                          docker-engine-selinux \
                          docker-engine
              sudo dnf -y install dnf-plugins-core
              sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
              printf "Official GPG key:\n     060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35\n\n"
              sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              sudo usermod -aG docker $USER
              sudo systemctl enable --now docker
            else
              printf "install package docker to use the wizard installer\nPlease refer to: https://docs.docker.com/engine/install/"
              exit 1
            fi
            ;;
          *)
            main
            ;;
        esac
    else
        echo "You canceled."
    fi
  else
   printf "docker found\n"
  fi
}
determine_editor() {
  CHOICE=$($WIZARD --title "Telemetry" --menu "Choose editor:" 15 60 4 \
    "1" "nano" \
    "2" "vim" \
    "3" "emacs" \
    "4" "code" \
    "4" "codium" \
    "b" "Back" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then
      case $CHOICE in
        "1")
          EDITOR="nano"
          ;;
        "2")
          EDITOR="vim"
          ;;
        "3")
          EDITOR="emacs"
          ;;
        "4")
          EDITOR="code"
          ;;
        "5")
          EDITOR="codium"
          ;;
        *)
          main
          ;;
      esac
  else
      echo "You canceled."
  fi
}

edit_config() {
  CHOICE=$($WIZARD --title "Telemetry" --menu "Choose config file to edit:" 15 60 4 \
    "1" "docker compose" \
    "2" ".env" \
    "3" "alloy" \
    "b" "Back" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then
      case $CHOICE in
        "1")
          determine_editor
          $EDITOR docker-compose.yml
          edit_config
          ;;
        "2")
          determine_editor
          $EDITOR .env
          edit_config
          ;;
        "3")
          determine_editor
          $EDITOR alloy/config.alloy
          edit_config
          ;;
        *)
          main
          ;;
      esac
  else
      echo "You canceled."
  fi
}

replace_env_variable(){
  KEY=$1
  VALUE=$2
  search_text=$(grep -i "$KEY" ".env")
  replace_text="$KEY=$VALUE"
  sed -i "s|$search_text|$replace_text|g" ".env"
}
pre_allocate_limits(){
  # 1. Get total physical RAM in KiB from /proc/meminfo
  TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  TOTAL_RAM_GIB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print kb / 1048576 }')

  # 2. Check 48 GiB threshold
  IS_LARGE_HOST=$(awk -v ram="$TOTAL_RAM_GIB" 'BEGIN { print (ram >= 48) ? 1 : 0 }')

  if [ "$IS_LARGE_HOST" -eq 1 ]; then
    # Host >= 48 GiB: Unlimited for Alloy & Grafana
    ALLOY_MEM_LIMIT=""
    GRAFANA_MEM_LIMIT=""

    # Loki limits
    LOKI_MEM_LIMIT="8G"
    LOKI_GOMEMLIMIT="6.4GiB"

    # Allocate 80% of total host RAM to InfluxDB 3 stack budget
    INFLUX_STACK_BUDGET_KB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print kb * 0.80 }')
  else
    # Host < 48 GiB: Fixed sidecar limits (1G Alloy, 2G Grafana, 4G Loki = 7G reserved)
    ALLOY_MEM_LIMIT="1G"
    GRAFANA_MEM_LIMIT="2G"
    LOKI_MEM_LIMIT="4G"
    LOKI_GOMEMLIMIT="3.2GiB"

    # Subtract 7 GiB (7340032 KiB) for sidecars, then allocate 80% of remaining RAM to Influx 3
    REMAINING_RAM_KB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print (kb - 7340032 > 0) ? kb - 7340032 : kb * 0.5 }')
    INFLUX_STACK_BUDGET_KB=$(awk -v kb="$REMAINING_RAM_KB" 'BEGIN { print kb * 0.80 }')
  fi

  # 3. Calculate InfluxDB 3 memory allocations
  # Container hard limit (80% of Influx budget)
  INFLUX_CONTAINER_LIMIT=$(awk -v kb="$INFLUX_STACK_BUDGET_KB" 'BEGIN { printf "%.0fG", (kb * 0.8) / 1048576 }')

  # Total Rust process max memory in Bytes (80% of container limit = ~64% of budget)
  INFLUX3_MAX_MEMORY_BYTES=$(awk -v kb="$INFLUX_STACK_BUDGET_KB" 'BEGIN { printf "%.0f", (kb * 0.8 * 0.8) * 1024 }')

  # Query pool: 50% of the total process memory limit
  INFLUX3_QUERY_MEMORY_POOL_BYTES=$(awk -v bytes="$INFLUX3_MAX_MEMORY_BYTES" 'BEGIN { printf "%.0f", bytes * 0.50 }')

  # Single query cap: 25% of the total query pool
  INFLUX3_SINGLE_QUERY_MEMORY_LIMIT_BYTES=$(awk -v bytes="$INFLUX3_QUERY_MEMORY_POOL_BYTES" 'BEGIN { printf "%.0f", bytes * 0.25 }')
  replace_env_variable "INFLUX3_MAX_MEMORY_BYTES" "${INFLUX3_MAX_MEMORY_BYTES}"
  replace_env_variable "INFLUX3_QUERY_MEMORY_POOL_BYTES" "${INFLUX3_QUERY_MEMORY_POOL_BYTES}"
  replace_env_variable "INFLUX3_SINGLE_QUERY_MEMORY_LIMIT_BYTES" "${INFLUX3_SINGLE_QUERY_MEMORY_LIMIT_BYTES}"
  replace_env_variable "INFLUX_CONTAINER_MEM_LIMIT" "${INFLUX_CONTAINER_LIMIT}"
  replace_env_variable "ALLOY_MEM_LIMIT" "${ALLOY_MEM_LIMIT}"
  replace_env_variable "GRAFANA_MEM_LIMIT" "${GRAFANA_MEM_LIMIT}"
  replace_env_variable "LOKI_MEM_LIMIT" "${LOKI_MEM_LIMIT}"
  replace_env_variable "LOKI_GOMEMLIMIT" "${LOKI_GOMEMLIMIT}"
  printf "--- Configuration Generated ---\n"
  printf "Host Total RAM:                   ${TOTAL_RAM_GIB} GiB\n"
  printf "InfluxDB Container Limit:         ${INFLUX_CONTAINER_LIMIT}\n"
  printf "InfluxDB Max Memory (Bytes):      ${INFLUX3_MAX_MEMORY_BYTES}\n"
  printf "InfluxDB Query Pool (Bytes):      ${INFLUX3_QUERY_MEMORY_POOL_BYTES}\n"
  printf "InfluxDB Single Query Max (Bytes):${INFLUX3_SINGLE_QUERY_MEMORY_LIMIT_BYTES}\n"
  printf "Loki Container Limit:             ${LOKI_MEM_LIMIT}\n"
  printf "Loki GOMEMLIMIT:                  ${LOKI_GOMEMLIMIT}\n"
  printf "Alloy Limit:                      ${ALLOY_MEM_LIMIT:-No Limit}\n"
  printf "Grafana Limit:                    ${GRAFANA_MEM_LIMIT:-No Limit}\n"
  main
}
main() {
    PWD=$(pwd)
    IS_ROOT=$(df . --output=target | tail -n +2)
    SPACE_LEFT=$(df . -h --output=avail | tail -n +2)
    CHOICE=$($WIZARD --title "Telemetry on $HOST:$IS_ROOT" --menu "Welcome to the telemetry wizard. For a first setup, follow the steps below:
 1. Check for a container engine installation
  - If existing, should be shown below under \"Host\" as \"docker|podman is []..]\"
 2. Edit your config files
    - Change credentials in .env                  (optional)
    - Run option 1 \"Pre-allocate memory limits\"   (optional)
      - Check memory limits in .env               (optional)
 3. Install with or without rsyslog
For more information, read the README.md or online: https://github.com/arkona-technologies/telemetry-template
      
      Host: $HOST
      Disk: Partition: $IS_ROOT - Space left: $SPACE_LEFT
      Memory: Total: $TOTAL_RAM_GIB GiB
      $PODMAN
      $DOCKER" 32 100 6 \
    "1" "Pre-allocate memory limits" \
    "2" "Install - space left on this device: $SPACE_LEFT" \
    "3" "Install - without rsyslog" \
    "4" "Start telemetry" \
    "5" "Stop telemetry" \
    "6" "Edit config files" \
    "7" "Check/Install docker" \
    "8" "Check/Install podman" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $CHOICE in
          "1")
            pre_allocate_limits
            ;;
          "2")
            ./run.sh
            ;;
          "3")
            ./run.sh NO_SYSLOG=true
            ;;
          "4")
            $(which podman||which docker) compose --env-file .env -f docker-compose.yml up -d
            ;;
          "5")
            $(which podman||which docker) compose -f docker-compose.yml down
            ;;
          "6")
            edit_config
            ;;
          "7")
            check_for_docker
            ;;
          "8")
            check_for_podman
            ;;
        esac
    else
        echo "Wizard closed"
    fi
    exit 0
}

check_for_whiptail
main