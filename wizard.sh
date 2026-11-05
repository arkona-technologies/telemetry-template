#!/bin/env bash
source .env
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
EDITOR=
WIZARD=
OS=$(. /etc/os-release && echo "${ID}")
TOTAL_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
TOTAL_RAM_GIB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print kb / 1048576 }')
PODMAN=$(type podman)
DOCKER=$(type docker)
VSKLINK="https://www.dropbox.com/scl/fi/jjgmm7lisz0uxffs0kcjl/vsk-linux-x64?rlkey=xvafn0fbztpd670aim7ytz8iy&st=4bqroec7&dl=0"

check_for_vsk() {
  if ! command -v vsk 2>&1 >/dev/null
  then
    echo "vsk could not be found, trying to install"
    wget $VSKLINK
    sudo mv ./vsk-linux* /usr/local/bin/vsk
    sudo chmod +x /usr/local/bin/vsk
    exit 1
  else
    printf "vsk is installed\n"
  fi
}

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
setup_syslog() {
  local restore_e=0
  case "$-" in
    *e*) restore_e=1; set +e ;;
  esac

  local TMP_OUT
  TMP_OUT=$(mktemp)
  trap 'rm -f "$TMP_OUT"' RETURN

  # --- Default Values ---
  FORMAT="DEFAULT"
  PROTOCOL="UDP"
  KEEP_ALIVE=false
  ADDRESS="127.0.0.1:514"
  NAMESPACE="ns_rear"
  MACHINES="${BLADES//,/ }"
  STEP=1

  while true; do
    case "$STEP" in
      1)
        DEF_STATE="OFF"; [ "$FORMAT" = "DEFAULT" ] && DEF_STATE="ON"
        ISO_STATE="OFF"; [ "$FORMAT" = "ISO8601" ] && ISO_STATE="ON"

        whiptail --title "Step 1 of 6: Format" \
          --ok-button "Next" \
          --cancel-button "Cancel" \
          --radiolist "Select the output format:" 12 50 2 \
          "DEFAULT" "Standard default format" "$DEF_STATE" \
          "ISO8601" "ISO-standard format"     "$ISO_STATE" \
          2> "$TMP_OUT" </dev/tty
        EXIT_CODE=$?

        # Step 1 Cancel/ESC aborts
        if [ $EXIT_CODE -ne 0 ]; then
          whiptail --title "Aborted" --msgbox "Operation cancelled." 8 40 </dev/tty
          [ $restore_e -eq 1 ] && set -e
          return 1
        fi

        FORMAT=$(cat "$TMP_OUT")
        STEP=2
        ;;

      2)
        UDP_STATE="OFF"; [ "$PROTOCOL" = "UDP" ] && UDP_STATE="ON"
        TCP_STATE="OFF"; [ "$PROTOCOL" = "TCP" ] && TCP_STATE="ON"

        whiptail --title "Step 2 of 6: Protocol" \
          --ok-button "Next" \
          --cancel-button "Back" \
          --radiolist "Select the network protocol:" 12 50 2 \
          "UDP" "User Datagram Protocol" "$UDP_STATE" \
          "TCP" "Transmission Control Protocol" "$TCP_STATE" \
          2> "$TMP_OUT" </dev/tty
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 1 ]; then
          STEP=1
        elif [ $EXIT_CODE -ne 0 ]; then
          # ESC key (255)
          [ $restore_e -eq 1 ] && set -e
          return 1
        else
          PROTOCOL=$(cat "$TMP_OUT")
          STEP=3
        fi
        ;;

      3)
        whiptail --title "Step 3 of 6: Keep Alive" \
          --yes-button "Enable" \
          --no-button "Disable" \
          --yesno "Do you want to enable keep-alive?\n(Current: $KEEP_ALIVE)" 10 50 </dev/tty
        EXIT_CODE=$?

        # With --yesno: 0 = Enable, 1 = Disable
        if [ $EXIT_CODE -eq 0 ]; then
          KEEP_ALIVE=true
          STEP=4
        elif [ $EXIT_CODE -eq 1 ]; then
          KEEP_ALIVE=false
          STEP=4
        else
          # ESC key
          STEP=2
        fi
        ;;

      4)
        whiptail --title "Step 4 of 6: Destination Address" \
          --ok-button "Next" \
          --cancel-button "Back" \
          --inputbox "Enter destination address:" 10 55 "$ADDRESS" \
          2> "$TMP_OUT" </dev/tty
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 1 ]; then
          STEP=3
        elif [ $EXIT_CODE -ne 0 ]; then
          [ $restore_e -eq 1 ] && set -e
          return 1
        else
          ADDRESS=$(cat "$TMP_OUT")
          STEP=5
        fi
        ;;

      5)
        whiptail --title "Step 5 of 6: Blade addresses" \
          --ok-button "Next" \
          --cancel-button "Back" \
          --inputbox "Enter IP addresses:" 10 55 "$MACHINES" \
          2> "$TMP_OUT" </dev/tty
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 1 ]; then
          STEP=4
        elif [ $EXIT_CODE -ne 0 ]; then
          [ $restore_e -eq 1 ] && set -e
          return 1
        else
          MACHINES=$(cat "$TMP_OUT")
          STEP=6
        fi
        ;;
      6)
        NS_REAR_STATE="OFF"; [ "$NAMESPACE" = "ns_rear" ] && NS_REAR_STATE="ON"
        NS_FRONT_STATE="OFF"; [ "$NAMESPACE" = "ns_front" ] && NS_FRONT_STATE="ON"
        NS_P0_STATE="OFF"; [ "$NAMESPACE" = "ns_p0" ] && NS_P0_STATE="ON"
        NS_P1_STATE="OFF"; [ "$NAMESPACE" = "ns_p1" ] && NS_P1_STATE="ON"

        whiptail --title "Step 6 of 6: Port" \
          --ok-button "Next" \
          --cancel-button "Back" \
          --radiolist "Select the Port:" 12 50 4 \
          "ns_rear" "Rear MGMT Port (MGMT Module)" "$NS_REAR_STATE" \
          "ns_front" "Front MGMT Port (USB C)" "$NS_FRONT_STATE" \
          "ns_p0" "Top 100G Port" "$NS_P0_STATE" \
          "ns_p1" "Bottom 100G Port" "$NS_P1_STATE" \
          2> "$TMP_OUT" </dev/tty
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 1 ]; then
          STEP=5
        elif [ $EXIT_CODE -ne 0 ]; then
          # ESC key (255)
          [ $restore_e -eq 1 ] && set -e
          return 1
        else
          PORT=$(cat "$TMP_OUT")
          STEP=7
        fi
        ;;

      
      7)
        SUMMARY="Ready to run with the following settings:

  Format:      ${FORMAT}
  Protocol:    ${PROTOCOL}
  Keep Alive:  ${KEEP_ALIVE}
  Address:     ${ADDRESS}
  Blades:      ${MACHINES}
  On Port:     ${NAMESPACE}

Proceed with execution?"

        whiptail --title "Confirmation" \
          --yes-button "Run" \
          --no-button "Back" \
          --yesno "$SUMMARY" 16 55 </dev/tty
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 1 ]; then
          # "Back" button clicked
          STEP=6
        elif [ $EXIT_CODE -eq 0 ]; then
          break
        else
          # ESC key
          [ $restore_e -eq 1 ] && set -e
          return 0
        fi
        ;;
    esac
  done

  [ $restore_e -eq 1 ] && set -e

  clear
  echo "Executing with configured values:"
  echo "---------------------------------"
  echo "FORMAT:     $FORMAT"
  echo "PROTOCOL:   $PROTOCOL"
  echo "KEEP_ALIVE: $KEEP_ALIVE"
  echo "ADDRESS:    $ADDRESS"
  echo "BLADES:     $MACHINES"
  echo "ON PORT:    $NAMESPACE"

  vsk vm network-config --verbose "if(namespace == \"$NAMESPACE\") return { syslog: [{ address_with_port:\"$ADDRESS\", keep_alive:$KEEP_ALIVE, protocol:\"$PROTOCOL\", format: \"$FORMAT\"}] }" $MACHINES
}
edit_config() {
  CHOICE=$($WIZARD --title "Telemetry" --menu "Choose config file to edit:" 15 60 4 \
    "1" "docker-compose.yml" \
    "2" ".env" \
    "3" "alloy" \
    "4" "loki" \
    "b" "Back" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then
      case $CHOICE in
        "1")
          determine_edfitor
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
        "4")
          determine_editor
          $EDITOR loki/local-config.yaml
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

# 2. Check if host has 48 GiB or more RAM
IS_LARGE_HOST=$(awk -v ram="$TOTAL_RAM_GIB" 'BEGIN { print (ram >= 48) ? 1 : 0 }')

if [ "$IS_LARGE_HOST" -eq 1 ]; then
  # Host >= 48 GiB: No hard container limits for lightweight services
  ALLOY_MEM_LIMIT=""
  GRAFANA_MEM_LIMIT=""
  
  # Cap Loki at 8G container / 6.4GiB GOMEMLIMIT
  LOKI_MEM_LIMIT="8G"
  LOKI_GOMEMLIMIT="6.4GiB"
  
  # Allocate 80% budget for InfluxDB stack
  INFLUX_STACK_BUDGET_KB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print kb * 0.80 }')
else
  # Host < 48 GiB: Enforce explicit limits (1G Alloy, 2G Grafana, 4G Loki = 7G sidecar overhead)
  ALLOY_MEM_LIMIT="1G"
  GRAFANA_MEM_LIMIT="2G"
  LOKI_MEM_LIMIT="4G"
  LOKI_GOMEMLIMIT="3.2GiB"
  
  # Subtract 7 GiB (7340032 KiB) for sidecars, then assign 80% of remaining RAM to Influx
  REMAINING_RAM_KB=$(awk -v kb="$TOTAL_RAM_KB" 'BEGIN { print (kb - 7340032 > 0) ? kb - 7340032 : kb * 0.5 }')
  INFLUX_STACK_BUDGET_KB=$(awk -v kb="$REMAINING_RAM_KB" 'BEGIN { print kb * 0.80 }')
fi

# 3. Calculate InfluxDB limits based on allocated budget
# Container limit = 80% of Influx budget
INFLUX_CONTAINER_LIMIT=$(awk -v kb="$INFLUX_STACK_BUDGET_KB" 'BEGIN { printf "%.0fG", (kb * 0.8) / 1048576 }')
# GOMEMLIMIT = 80% of container limit
INFLUX_GOMEMLIMIT=$(awk -v kb="$INFLUX_STACK_BUDGET_KB" 'BEGIN { printf "%.2fGiB", (kb * 0.8 * 0.8) / 1048576 }')

replace_env_variable "INFLUX_CONTAINER_MEM_LIMIT" "${INFLUX_CONTAINER_LIMIT}"
replace_env_variable "INFLUX_GOMEMLIMIT" "${INFLUX_GOMEMLIMIT}"
replace_env_variable "ALLOY_MEM_LIMIT" "${ALLOY_MEM_LIMIT}"
replace_env_variable "GRAFANA_MEM_LIMIT" "${GRAFANA_MEM_LIMIT}"
replace_env_variable "LOKI_MEM_LIMIT" "${LOKI_MEM_LIMIT}"
replace_env_variable "LOKI_GOMEMLIMIT" "${LOKI_GOMEMLIMIT}"
printf "--- Configuration Generated ---\n"
printf "Host Total RAM:         ${TOTAL_RAM_GIB} GiB\n"
printf "Influx Container Limit: ${INFLUX_CONTAINER_LIMIT}\n"
printf "Influx GOMEMLIMIT:      ${INFLUX_GOMEMLIMIT}\n"
printf "Alloy Limit:            ${ALLOY_MEM_LIMIT:-No Limit}\n"
printf "Grafana Limit:          ${GRAFANA_MEM_LIMIT:-No Limit}\n"
printf "Loki Container Limit:   ${LOKI_MEM_LIMIT}\n"
printf "Loki GOMEMLIMIT:        ${LOKI_GOMEMLIMIT}\n"
}
main() {
    CHOICE=$($WIZARD --title "Telemetry" --menu "Welcome to the telemetry wizard.
For a first setup, do the following:
 1. Check for a container engine installation (docker or podman)
  - If existing, should be shown below under \"Host\"
 2. Edit your config files (usually only .env is necessary)
    - Run option 1 \"Pre-allocate memory limits\"   (optional)
      - Check memory limits in .env               (optional)
    - Change credentials in .env                  (optional)
 3. Install with or without rsyslog
For more information, refer to: https://github.com/arkona-technologies/telemetry-template

Host: 
  Total mem: $TOTAL_RAM_GIB GiB
  $PODMAN
  $DOCKER\n" 30 100 8 \
    "1" "Pre-allocate memory limits" \
    "2" "Install" \
    "3" "Install - without rsyslog" \
    "4" "Start telemetry" \
    "5" "Stop telemetry" \
    "6" "Edit config files" \
    "7" "Check/Install docker" \
    "8" "Check/Install podman" \
    "9" "Check/Install vsk" \
    "10" "Setup syslog on blades" 3>&1 1>&2 2>&3)

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
          "9")
            check_for_vsk
            ;;
          "10")
            # check_for_vsk
            setup_syslog
            ;;
        esac
    else
        echo "Wizard closed"
    fi
    exit 0
}

check_for_whiptail
main