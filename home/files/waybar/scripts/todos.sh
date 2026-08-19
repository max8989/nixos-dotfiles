#!/usr/bin/env bash

# Waybar module: count of open todos ("- [ ]" with actual content) in the
# Obsidian vault. Click handler: todo-menu.sh (rofi list of the same todos).
#
# NOTE: the grep below (pattern + exclusions) must stay in sync with
# todo-menu.sh and scripts/lockscreen-todos.sh (hyprlock).

set -uo pipefail

VAULT="$HOME/Documents/obsidian"

count=$(grep -rn --include='*.md' \
  --exclude-dir='Templates' --exclude-dir='90 Archive' \
  --exclude-dir='99 System' --exclude-dir='Obsidian' \
  --exclude-dir='Assets' --exclude-dir='.obsidian' --exclude-dir='.git' \
  --exclude='SETUP.md' --exclude='README.md' \
  --exclude='CLAUDE.md' --exclude='AGENTS.md' \
  -E '^[[:space:]]*[-*] \[ \][[:space:]]*[^[:space:]]' \
  "$VAULT" 2>/dev/null | wc -l)

if [ "$count" -eq 0 ]; then
  class="none"
  tooltip="No open todos"
else
  class="pending"
  tooltip="$count open todo(s) — click for the list"
fi

jq -cn --arg text "$count" --arg tooltip "$tooltip" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
