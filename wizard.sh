#!/bin/bash

EDITOR=
WIZARD=

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

  if ! command -v docfker 2>&1 >/dev/null
  then
    CHOICE=$($WIZARD --title "Install docker" --menu "No docker installation found.\nThis wizard can install it for you, but without guaranteed success. For more information, please refer to:\n - https://docs.docker.com/engine/install/\nPress 'y' to continue\n" 20 60 4 \
    "y" "Install podman" \
    "n" "Back" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $CHOICE in
          "y")
            if command -v apt 2>&1 >/dev/null
            then
              for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
              # Add Docker's official GPG key:
              sudo apt update
              sudo apt install ca-certificates curl
              sudo install -m 0755 -d /etc/apt/keyrings
              sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
              sudo chmod a+r /etc/apt/keyrings/docker.asc
              echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt update
              sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
              sudo groupadd docker
              sudo usermod -aG docker $USER
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
    "3" "promtail" \
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
          $EDITOR promtail/config.yml
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

main() {
    CHOICE=$($WIZARD --title "Telemetry" --menu "Welcome to the telemetry wizard.\nFor a first setup, do the following:\n - check for a container engine installation first (docker or podman)\n - edit your config files (usually only .env is necessary)\n - Install with or without rsyslog\nFor more information, refer to: https://github.com/arkona-technologies/telemetry-template" 22 80 6 \
    "1" "Install" \
    "2" "Install - without rsyslog" \
    "3" "Start telemetry" \
    "4" "Stop telemetry" \
    "5" "Edit config files" \
    "6" "Check for docker" \
    "7" "Check for podman" 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        case $CHOICE in
          "1")
            ./run.sh
            ;;
          "2
          ")
            ./run.sh NO_SYSLOG=true
            ;;
          "3")
            $(which podman||which docker) compose --env-file .env -f docker-compose.yml up -d
            ;;
          "4")
            $(which podman||which docker) compose -f docker-compose.yml down
            ;;
          "5")
            edit_config
            ;;
          "6")
            check_for_docker
            ;;
          "7")
            check_for_podman
            ;;
          *)
            printf "You canceled."
            ;;
        esac
    else
        echo "You canceled."
    fi
    exit 0
}

check_for_whiptail
main