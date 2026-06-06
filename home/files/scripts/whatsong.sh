#!/bin/bash

# Check if playerctl is installed
if ! command -v playerctl &> /dev/null; then
    echo "playerctl could not be found. Please install it."
    exit 1
fi

# Get the currently playing song information
song_title=$(playerctl metadata title 2> /dev/null)
artist_name=$(playerctl metadata artist 2> /dev/null)

# Format the output in one line
if [ "$song_title" != "" ]; then
    echo "Now Playing: $song_title by $artist_name"
fi
