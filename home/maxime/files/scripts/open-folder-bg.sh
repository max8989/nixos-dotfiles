#!/bin/bash

# Check if rofi is already open (only works if you name the window)
pid=$(pgrep -f "rofi -dmenu -p Open\ file\ location")

if [ -n "$pid" ]; then
  kill "$pid"  # Toggle off
else
  (
    selected=$(fd . ~ | rofi -dmenu -p "Open file location")
    if [ -n "$selected" ]; then
      nautilus "$(dirname "$selected")"
    fi
  ) &
fi
