#!/bin/bash

EDITOR=

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
}
determine_editor() {
  CHOICE=$(whiptail --title "Telemetry" --menu "Choose editor:" 15 60 4 \
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
  CHOICE=$(whiptail --title "Telemetry" --menu "Choose config file to edit:" 15 60 4 \
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
    CHOICE=$(whiptail --title "Telemetry" --menu "Choose your action:" 15 60 6 \
    "1" "Install" \
    "2" "Install - without rsyslog" \
    "3" "Start telemetry" \
    "4" "Stop telemetry" \
    "5" "Edit config files" 3>&1 1>&2 2>&3)

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