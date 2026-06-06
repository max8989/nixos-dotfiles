#!/bin/bash
# Screenshot wrapper: copies path to clipboard, then image

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
FILENAME="$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$SCREENSHOT_DIR/$FILENAME"

# Take screenshot with hyprshot (pass all arguments)
hyprshot -o "$SCREENSHOT_DIR" -f "$FILENAME" "$@"

# Check if screenshot was created
if [[ -f "$FILEPATH" ]]; then
    # Copy path to clipboard — pasting into Claude lets it Read the image directly
    echo -n "$FILEPATH" | wl-copy
fi
