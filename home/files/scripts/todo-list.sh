#!/usr/bin/env bash

# Single source of truth for the reminders list: the unchecked todos in the
# dedicated Obsidian TODO note. Prints one cleaned task per line ("- [ ]"
# stripped, wikilinks unwrapped, blanks dropped).
#
# Consumed by scripts/lockscreen-todos.sh (hyprlock label) and by
# waybar/scripts/todos.sh + todo-menu.sh (count + rofi list), so the bar and
# the lock screen always show the same reminders. Change the source note or
# the pattern here, nowhere else.

set -uo pipefail

TODO_FILE="${TODO_FILE:-$HOME/Documents/obsidian/Templates/TODO.md}"

grep -E '^[[:space:]]*[-*] \[ \][[:space:]]*[^[:space:]]' "$TODO_FILE" 2>/dev/null |
  sed -E -e 's/^[[:space:]]*[-*] \[ \][[:space:]]*//' \
    -e 's/\[\[([^]|]*\|)?([^]]+)\]\]/\2/g' \
    -e 's/[[:space:]]+$//' |
  sed '/^$/d'
