#!/usr/bin/env bash

# Check if playerctl is installed
if ! command -v playerctl &> /dev/null; then
    echo "playerctl could not be found. Please install it."
    exit 1
fi

# Keep the line short enough that the centered hyprlock label can't run
# into the top-left system status or the top-right battery/weather labels.
MAX_LEN=60

# Get the currently playing song information
song_title=$(playerctl metadata title 2> /dev/null)
artist_name=$(playerctl metadata artist 2> /dev/null)

# Format the output in one line
if [ "$song_title" != "" ]; then
    line="$song_title"
    [ -n "$artist_name" ] && line="$line by $artist_name"
    [ "${#line}" -gt "$MAX_LEN" ] && line="${line:0:MAX_LEN}…"
    echo "Now Playing: $line"
fi
