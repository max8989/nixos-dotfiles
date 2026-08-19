#!/usr/bin/env bash

# Cached wttr.in weather for the hyprlock top bar (Traditional Chinese).
# Prints e.g. "天氣: 多雲 22°C". Serves the last cached value when offline.
CACHE_DIR="$HOME/.cache/hyprlock"
CACHE="$CACHE_DIR/weather"
mkdir -p "$CACHE_DIR"

out=$(curl -sf --max-time 3 'https://wttr.in/?format=%C+%t&lang=zh-tw' 2>/dev/null | tr -d '+')
if [ -n "$out" ] && ! printf '%s' "$out" | grep -qiE 'unknown|error|sorry'; then
  printf '天氣: %s' "$out" > "$CACHE"
fi

cat "$CACHE" 2>/dev/null
