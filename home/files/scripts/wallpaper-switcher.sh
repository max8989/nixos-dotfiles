#!/bin/bash

# Directory containing wallpapers
WALLPAPER_DIR="$HOME/.config/backgrounds"
HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
STATE_FILE="$HOME/.cache/current_wallpaper_index"

# Get list of wallpapers
WALLPAPERS=("$WALLPAPER_DIR"/*.{png,jpg,jpeg})
# Remove non-existent patterns
WALLPAPERS=($(ls $WALLPAPER_DIR/*.{png,jpg,jpeg} 2>/dev/null))

# Check if any wallpapers exist
if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "Wallpaper Switcher" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# Read current index from state file, default to 0
if [ -f "$STATE_FILE" ]; then
    CURRENT_INDEX=$(cat "$STATE_FILE")
else
    CURRENT_INDEX=0
fi

# Calculate next index (cycle through wallpapers)
NEXT_INDEX=$(( (CURRENT_INDEX + 1) % ${#WALLPAPERS[@]} ))

# Get the next wallpaper path
NEXT_WALLPAPER="${WALLPAPERS[$NEXT_INDEX]}"

# Update hyprpaper configuration
cat > "$HYPRPAPER_CONF" << EOF
preload = $NEXT_WALLPAPER
wallpaper = , $NEXT_WALLPAPER
EOF

# Reload hyprpaper
killall hyprpaper 2>/dev/null
hyprpaper &

# Save current index
echo "$NEXT_INDEX" > "$STATE_FILE"

# Notify user
WALLPAPER_NAME=$(basename "$NEXT_WALLPAPER")
notify-send "Wallpaper Switched" "$WALLPAPER_NAME" -i "$NEXT_WALLPAPER" -t 2000