#!/usr/bin/env bash
set -euo pipefail
[[ $# == 1 && -f $1 ]] || exit 1
FILE=$1
ACTION=$(notify-send --app-name "Screen Recording" --icon video-display \
  --expire-time=10000 --action "open=Open" --action "folder=Open folder" \
  --action "copy=Copy path" --wait "Screen recording saved" "$FILE") || exit 0
case "$ACTION" in
  open) exec xdg-open "$FILE" ;;
  folder) exec xdg-open "${FILE%/*}" ;;
  copy) printf '%s' "$FILE" | wl-copy ;;
esac
