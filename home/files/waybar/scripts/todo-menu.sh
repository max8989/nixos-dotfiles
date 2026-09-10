#!/usr/bin/env bash

# SwiftBar-style dropdown of open Obsidian todos (waybar custom/todos click
# handler): rofi anchored at the click via rofi-anchor.sh, entry bar hidden,
# height fit to content, single left click accepts. Rows: the todos from the
# dedicated TODO note, then Open TODO / Open Home / Refresh. Picking a todo
# opens that note in Obsidian via the obsidian:// URI.
#
# The tasks come from scripts/todo-list.sh — the same list the hyprlock label
# renders, so this menu mirrors the lock screen exactly.

set -euo pipefail

# Toggle: reclicking the module while a menu is open closes it.
if pkill -x rofi 2>/dev/null; then
  exit 0
fi

VAULT="$HOME/Documents/obsidian"
VAULT_NAME=$(basename "$VAULT")
HOME_NOTE="00 Home/Home"
TODO_NOTE="Templates/TODO" # vault-relative, matches scripts/todo-list.sh

DIM="#66788CFF" # muted gray-blue (matches fgp-color in rofi/config.rasi)

# Menu look: no search entry, content-sized height, roomy rounded rows.
DROPDOWN='mainbox{children:[listview];}
window{width:640px;}
listview{lines:14;fixed-height:false;spacing:2px;}
element{padding:8px 12px;border-radius:10px;}'

anchor=$(~/.config/waybar/scripts/rofi-anchor.sh 640 2>/dev/null || true)
rofi_args=(
  -dmenu -i -format i -markup-rows
  -me-select-entry '' -me-accept-entry MousePrimary # single click accepts
  -theme-str "$DROPDOWN"
)
[ -n "$anchor" ] && rofi_args+=(-theme-str "$anchor")

# Pango-escape for display (todo-list.sh already unwrapped [[wikilinks]]).
# The backslashes are required: since bash 5.2 a bare "&" in a pattern-
# substitution replacement expands to the matched text, so "&lt;" would come
# out as "<lt;".
pretty() {
  local s=$1
  s=${s//&/\&amp;}
  s=${s//</\&lt;}
  s=${s//>/\&gt;}
  printf '%s' "$s"
}

texts=()
while IFS= read -r line; do
  texts+=("$line")
done < <("$HOME/.config/scripts/todo-list.sh")

# One row per task, dimmed bullet + task text.
menu=""
for text in ${texts[@]+"${texts[@]}"}; do
  menu+="<span foreground='${DIM}'>󰄰</span>  $(pretty "$text")"$'\n'
done

# The "all done" placeholder is a row too, so it counts as one (it maps to
# the TODO note, same as a task row would).
count=${#texts[@]}
if [ "$count" -eq 0 ]; then
  menu+="<span foreground='${DIM}'>✓ No open todos</span>"$'\n'
  count=1
fi

menu+="󰄲  Open TODO"$'\n'
menu+="󰋜  Open Home"$'\n'
menu+="󰑐  Refresh"$'\n'

# -format i → rofi prints the selected row index (labels are not unique).
index=$(printf '%s' "$menu" | rofi "${rofi_args[@]}" -p "󰄲 ") || exit 0
[ -n "$index" ] || exit 0

if [ "$index" -le "$count" ]; then
  target="$TODO_NOTE" # a todo row, or the "Open TODO" row itself
elif [ "$index" -eq $((count + 1)) ]; then
  target="$HOME_NOTE"
else
  pkill -RTMIN+8 waybar # re-run todos.sh (custom/todos has "signal": 8)
  exit 0
fi

encoded=$(jq -rn --arg s "$target" '$s|@uri')
xdg-open "obsidian://open?vault=${VAULT_NAME}&file=${encoded}" >/dev/null 2>&1 &
