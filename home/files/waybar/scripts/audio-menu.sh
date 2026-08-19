#!/usr/bin/env bash

# Audio output selector — rofi replacement for hyprwat (AUR-only, never
# packaged for NixOS). Lists PipeWire sinks via pactl and switches the
# default sink; active streams follow automatically (pipewire-pulse).
# Themed by ~/.config/rofi/config.rasi like the other rofi menus.

set -euo pipefail

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
    menu+="󰓃 ${descs[$i]}  ✓"$'\n'
  else
    menu+="󰓃 ${descs[$i]}"$'\n'
  fi
done

# -format i → rofi prints the selected row index, so no need to parse the
# label back (descriptions are not guaranteed unique).
index=$(printf '%s' "$menu" | rofi -dmenu -i -p "󰕾 " -format i) || exit 0
[ -n "$index" ] || exit 0

pactl set-default-sink "${names[$index]}"
notify-send -a "audio" "Audio output" "${descs[$index]}" -i "audio-speakers" -r 9992
