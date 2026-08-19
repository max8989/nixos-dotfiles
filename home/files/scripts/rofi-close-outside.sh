#!/usr/bin/env bash

# Fired by a non-consuming Hyprland bind on every left click (see
# keybindings.lua). Closes rofi when the click lands outside its window —
# rofi 2.0.0's wayland backend cannot see clicks outside its own surface
# (upstream click-to-exit landed only after the 2.0.0 release).
# Clicks inside waybar are ignored here: the bar's module scripts
# (todo-menu.sh / audio-menu.sh) toggle rofi themselves, and killing it from
# both sides would race and reopen the menu.

pgrep -x rofi >/dev/null 2>&1 || exit 0

eval "$(hyprctl cursorpos -j | jq -r '@sh "cx=\(.x) cy=\(.y)"')"

while IFS=$'\t' read -r x y w h; do
  if [ "$cx" -ge "$x" ] && [ "$cx" -lt "$((x + w))" ] &&
    [ "$cy" -ge "$y" ] && [ "$cy" -lt "$((y + h))" ]; then
    exit 0
  fi
done < <(hyprctl layers -j | jq -r '
  .. | objects
  | select(.namespace? == "rofi" or .namespace? == "waybar")
  | [.x, .y, .w, .h] | @tsv')

pkill -x rofi
