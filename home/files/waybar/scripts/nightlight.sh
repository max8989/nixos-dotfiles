#!/usr/bin/env bash

# Waybar module: night light (blue-light filter) toggle.
#
# Drives the hyprsunset daemon (services.hyprsunset in home/desktop.nix) over
# its hyprctl IPC:
#   hyprctl hyprsunset temperature 4000   # warm
#   hyprctl hyprsunset identity           # back to neutral
#
# hyprsunset exposes setters only — there is no "read the current temperature"
# call — so the active setting is mirrored in a runtime state file. That file
# lives in $XDG_RUNTIME_DIR, so it is wiped on logout and the module comes back
# up "off", which matches a freshly started hyprsunset (identity).
#
# Usage: nightlight.sh [status|toggle|up|down]   (default: status)

set -uo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-nightlight"

DEFAULT_TEMP=4000 # what a plain toggle turns on
MIN_TEMP=2500     # warmest (deep amber)
MAX_TEMP=6000     # hyprsunset's neutral default
STEP=500

WAYBAR_SIGNAL=9 # must match `signal` on custom/nightlight in home/waybar.nix

current_temp() {
  [ -r "$STATE" ] && cat "$STATE" 2>/dev/null || echo ""
}

refresh_waybar() {
  pkill -RTMIN+$WAYBAR_SIGNAL waybar 2>/dev/null
  return 0
}

apply() {
  local temp="$1"
  if ! hyprctl hyprsunset temperature "$temp" >/dev/null 2>&1; then
    notify-send -u critical "Night light" "hyprsunset is not responding" 2>/dev/null
    return 1
  fi
  echo "$temp" >"$STATE"
  refresh_waybar
}

turn_off() {
  if ! hyprctl hyprsunset identity >/dev/null 2>&1; then
    notify-send -u critical "Night light" "hyprsunset is not responding" 2>/dev/null
    return 1
  fi
  rm -f "$STATE"
  refresh_waybar
}

case "${1:-status}" in
toggle)
  if [ -n "$(current_temp)" ]; then turn_off; else apply "$DEFAULT_TEMP"; fi
  ;;

# Scroll: warmer / cooler. Scrolling while off starts from the neutral end, so
# the first notch down already tints the screen.
down) # warmer
  temp=$(current_temp)
  temp=$((${temp:-$MAX_TEMP} - STEP))
  [ "$temp" -lt "$MIN_TEMP" ] && temp=$MIN_TEMP
  apply "$temp"
  ;;
up) # cooler — stepping back to neutral turns the filter off
  temp=$(current_temp)
  [ -z "$temp" ] && exit 0
  temp=$((temp + STEP))
  if [ "$temp" -ge "$MAX_TEMP" ]; then turn_off; else apply "$temp"; fi
  ;;

status)
  temp=$(current_temp)
  if [ -n "$temp" ]; then
    printf '{"text": "󰖔", "class": "active", "tooltip": "Night light ON — %sK\\nClick to turn off · scroll to adjust"}\n' "$temp"
  else
    printf '{"text": "󰖙", "class": "inactive", "tooltip": "Night light OFF\\nClick for %sK · scroll down for warmer"}\n' "$DEFAULT_TEMP"
  fi
  ;;

*)
  echo "usage: $(basename "$0") [status|toggle|up|down]" >&2
  exit 1
  ;;
esac
