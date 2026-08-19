#!/usr/bin/env bash

# Audio output selector — rofi replacement for hyprwat (AUR-only, never
# packaged for NixOS). Lists PipeWire sinks via pactl and switches the
# default sink; active streams follow automatically (pipewire-pulse).
# SwiftBar-style dropdown anchored at the click (rofi-anchor.sh), entry bar
# hidden, single left click accepts; the active sink gets a green check.

set -euo pipefail

# Toggle: reclicking the module while a menu is open closes it.
if pkill -x rofi 2>/dev/null; then
  exit 0
fi

ACCENT="#00FF99" # active-state green (matches #battery.charging in waybar css)

DROPDOWN='mainbox{children:[listview];}
window{width:640px;}
listview{lines:10;fixed-height:false;spacing:2px;}
element{padding:8px 12px;border-radius:10px;}'

anchor=$(~/.config/waybar/scripts/rofi-anchor.sh 640 2>/dev/null || true)
rofi_args=(
  -dmenu -i -format i -markup-rows
  -me-select-entry '' -me-accept-entry MousePrimary # single click accepts
  -theme-str "$DROPDOWN"
)
[ -n "$anchor" ] && rofi_args+=(-theme-str "$anchor")

# Pango-escape for -markup-rows.
esc() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  printf '%s' "$s"
}

default_sink=$(pactl get-default-sink)

# Parallel arrays: sink names and their human-readable descriptions.
names=()
descs=()
while IFS=$'\t' read -r name desc; do
  names+=("$name")
  descs+=("$desc")
done < <(pactl -f json list sinks | jq -r '.[] | "\(.name)\t\(.description)"')

[ "${#names[@]}" -gt 0 ] || exit 0

menu=""
for i in "${!names[@]}"; do
  if [ "${names[$i]}" = "$default_sink" ]; then
    menu+="󰓃  $(esc "${descs[$i]}")  <span foreground='${ACCENT}'>✓</span>"$'\n'
  else
    menu+="󰓃  $(esc "${descs[$i]}")"$'\n'
  fi
done

# -format i → rofi prints the selected row index (labels are not unique).
index=$(printf '%s' "$menu" | rofi "${rofi_args[@]}" -p "󰕾 ") || exit 0
[ -n "$index" ] || exit 0

pactl set-default-sink "${names[$index]}"
notify-send -a "audio" "Audio output" "${descs[$index]}" -i "audio-speakers" -r 9992
