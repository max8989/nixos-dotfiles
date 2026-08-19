#!/usr/bin/env bash

# SwiftBar-style dropdown of open Obsidian todos (waybar custom/todos click
# handler): rofi anchored at the click via rofi-anchor.sh, entry bar hidden,
# height fit to content, single left click accepts. Rows: todos first (task
# text + dimmed note name via pango markup), then Open Home / Refresh.
# Picking a todo opens its note in Obsidian via the obsidian:// URI.
#
# NOTE: the grep below (pattern + exclusions) must stay in sync with todos.sh.

set -euo pipefail

# Toggle: reclicking the module while a menu is open closes it.
if pkill -x rofi 2>/dev/null; then
  exit 0
fi

VAULT="$HOME/Documents/obsidian"
VAULT_NAME=$(basename "$VAULT")
HOME_NOTE="00 Home/Home"

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

# Pango-escape + drop [[wiki brackets]] for display.
pretty() {
  local s=$1
  s=${s//\[\[/}
  s=${s//\]\]/}
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  printf '%s' "$s"
}

# -Z NUL-terminates the filename, so paths containing ":" parse safely.
rels=()
texts=()
while IFS= read -r -d '' file && IFS= read -r rest; do
  texts+=("$(sed -E 's/^[[:space:]]*[-*] \[ \][[:space:]]*//' <<<"${rest#*:}")")
  rels+=("${file#"$VAULT/"}")
done < <(grep -rnZ --include='*.md' \
  --exclude-dir='Templates' --exclude-dir='90 Archive' \
  --exclude-dir='99 System' --exclude-dir='Obsidian' \
  --exclude-dir='Assets' --exclude-dir='.obsidian' --exclude-dir='.git' \
  --exclude='SETUP.md' --exclude='README.md' \
  --exclude='CLAUDE.md' --exclude='AGENTS.md' \
  -E '^[[:space:]]*[-*] \[ \][[:space:]]*[^[:space:]]' \
  "$VAULT" 2>/dev/null || true)

# Project todos first, then everything else. The note label (a date for
# daily notes) leads each row, dimmed; the task text follows.
menu=""
files=()
for pass in projects rest; do
  for i in "${!rels[@]}"; do
    rel=${rels[$i]}
    case $pass in
      projects) [[ $rel == "10 Projects/"* ]] || continue ;;
      rest) [[ $rel == "10 Projects/"* ]] && continue ;;
    esac
    note=$(basename "$rel" .md)
    files+=("$rel")
    menu+="<span size='small' foreground='${DIM}'>$(pretty "$note")</span>  $(pretty "${texts[$i]}")"$'\n'
  done
done

count=${#files[@]}
menu+="󰋜  Open Home"$'\n'
menu+="󰑐  Refresh"$'\n'

# -format i → rofi prints the selected row index (labels are not unique).
index=$(printf '%s' "$menu" | rofi "${rofi_args[@]}" -p "󰄲 ") || exit 0
[ -n "$index" ] || exit 0

if [ "$index" -lt "$count" ]; then
  target="${files[$index]%.md}"
elif [ "$index" -eq "$count" ]; then
  target="$HOME_NOTE"
else
  pkill -RTMIN+8 waybar # re-run todos.sh (custom/todos has "signal": 8)
  exit 0
fi

encoded=$(jq -rn --arg s "$target" '$s|@uri')
xdg-open "obsidian://open?vault=${VAULT_NAME}&file=${encoded}" >/dev/null 2>&1 &
