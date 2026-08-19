#!/usr/bin/env bash

# Prints a rofi -theme-str snippet that centers the window horizontally on
# the cursor, just below the bar — so menus drop from the middle of the
# clicked waybar module (SwiftBar-style). Clamped so the menu never runs off
# the screen. Usage: rofi-anchor.sh [menu-width-px] (default 640; pass the
# same width the caller sets on window{width:...}).

set -euo pipefail

MENU_W=${1:-640}

# Layer-shell margins are measured from the *usable* area, i.e. already below
# waybar's exclusive zone — keep this a small gap, not the bar height.
Y_OFFSET=6
EDGE_MARGIN=8

cx=$(hyprctl cursorpos -j | jq -r '.x')

mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused == true)')
mx=$(jq -r '.x' <<<"$mon")
mw=$(jq -r '(.width / .scale) | floor' <<<"$mon")

cx=$((cx - mx))

# Center on the click, clamped to the screen edges.
x_off=$((cx - MENU_W / 2))
max_x=$((mw - MENU_W - EDGE_MARGIN))
[ "$x_off" -gt "$max_x" ] && x_off=$max_x
[ "$x_off" -lt "$EDGE_MARGIN" ] && x_off=$EDGE_MARGIN

printf 'window{location:north west;anchor:north west;x-offset:%dpx;y-offset:%dpx;}' \
  "$x_off" "$Y_OFFSET"
