#!/usr/bin/env bash

# Waybar module: count of open todos in the dedicated Obsidian TODO note.
# Click handler: todo-menu.sh (rofi list of the same todos).
#
# The list comes from scripts/todo-list.sh, which the hyprlock label
# (scripts/lockscreen-todos.sh) reads too — bar and lock screen stay in sync
# by construction, so there is nothing to keep in sync by hand here.

set -uo pipefail

count=$("$HOME/.config/scripts/todo-list.sh" | wc -l)

if [ "$count" -eq 0 ]; then
  class="none"
  tooltip="No open todos"
else
  class="pending"
  tooltip="$count open todo(s) — click for the list"
fi

jq -cn --arg text "$count" --arg tooltip "$tooltip" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
