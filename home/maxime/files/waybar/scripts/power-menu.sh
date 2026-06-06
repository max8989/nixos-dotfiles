#!/usr/bin/env bash

# Close wofi if already running
if pidof wofi > /dev/null; then
    killall wofi
    exit 0
fi

# i3-style power menu options
actions=$(echo -e "  Lock\n  Shutdown\n  Reboot\n  Suspend\n  Hibernate\n  Logout")

# Display power menu using wofi with i3 style
selected_option=$(echo -e "$actions" | wofi \
    --dmenu \
    --prompt "" \
    --width 350 \
    --height 280 \
    --style "$HOME/.config/wofi/power-menu.css" \
    --hide-scroll \
    --cache-file=/dev/null \
    -p "")

# Perform actions based on the selected option
case "$selected_option" in
*Lock)
  hyprlock
  ;;
*Shutdown)
  systemctl poweroff
  ;;
*Reboot)
  systemctl reboot
  ;;
*Suspend)
  systemctl suspend
  ;;
*Hibernate)
  systemctl hibernate
  ;;
*Logout)
  loginctl kill-session "$XDG_SESSION_ID"
  ;;
esac
