#!/usr/bin/env bash

# Check if rofi is already open (only works if you name the window)
pid=$(pgrep -f "rofi -dmenu -p Open\ file\ location")

if [ -n "$pid" ]; then
  kill "$pid"  # Toggle off
else
  (
    selected=$(fd . ~ | rofi -dmenu -p "Open file location")
    if [ -n "$selected" ]; then
      # --select opens the containing folder with the file highlighted,
      # which the old `nautilus "$(dirname …)"` could not do.
      dolphin --select "$selected"
    fi
  ) &
fi
