#!/usr/bin/env bash

# Print a filesystem path to the current track's album art, for hyprlock's
# image widget (reload_cmd). Prints a transparent placeholder when nothing
# is playing, which effectively hides the widget.
PLACEHOLDER="$HOME/.config/hypr/assets/transparent.png"
CACHE_DIR="$HOME/.cache/hyprlock"
mkdir -p "$CACHE_DIR"

status=$(playerctl status 2>/dev/null)
url=$(playerctl metadata mpris:artUrl 2>/dev/null)
if [ "$status" != "Playing" ] || [ -z "$url" ]; then
  echo "$PLACEHOLDER"
  exit 0
fi

case "$url" in
  file://*)
    path="${url#file://}"
    [ -f "$path" ] && echo "$path" || echo "$PLACEHOLDER"
    ;;
  http*)
    art="$CACHE_DIR/albumart"
    key="$CACHE_DIR/albumart.url"
    if [ ! -f "$key" ] || [ "$(cat "$key" 2>/dev/null)" != "$url" ]; then
      if curl -sf --max-time 3 -o "$art.tmp" "$url"; then
        mv "$art.tmp" "$art"
        printf '%s' "$url" > "$key"
      fi
    fi
    [ -f "$art" ] && echo "$art" || echo "$PLACEHOLDER"
    ;;
  *)
    echo "$PLACEHOLDER"
    ;;
esac
