#!/usr/bin/env bash
# Adapted from Omarchy 4.0.0.alpha; see ../omarchy/PROVENANCE.md and LICENSE.
# screenshot.sh [smart|region|windows|fullscreen] [slurp|copy|save|ocr|qr]
# Default: save a PNG, copy its image, print its path, and offer editing.
set -euo pipefail
umask 077

MODE=${1:-smart}
PROCESSING=${2:-slurp}
case "$MODE" in smart|region|windows|fullscreen) ;; *) echo "Invalid capture mode: $MODE" >&2; exit 2 ;; esac
case "$PROCESSING" in slurp|copy|save|ocr|qr) ;; *) echo "Invalid processing mode: $PROCESSING" >&2; exit 2 ;; esac

CAPTURE_RUNTIME="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nixos-capture-$UID"
mkdir -p "$CAPTURE_RUNTIME"
exec 9> "$CAPTURE_RUNTIME/capture.lock"
if ! flock -n 9; then
  nixos-capture-region --cancel
  exit 0
fi

# Restore cursor composition even after picker/capture errors. Only alter it
# if Hyprland returned a valid numeric setting and accepted the change.
NO_HW_CURSORS=""
CURSOR_CHANGED=false
EXTRACT_FILE=""
set_no_hw_cursors() {
  hyprctl eval "hl.config({ cursor = { no_hardware_cursors = $1 } })" >/dev/null 2>&1
}
cleanup() {
  nixos-capture-region --cancel || true
  if [[ $CURSOR_CHANGED == true ]]; then set_no_hw_cursors "$NO_HW_CURSORS" || true; fi
  rm -f "$CAPTURE_RUNTIME/result"
  if [[ -n $EXTRACT_FILE ]]; then rm -f "$EXTRACT_FILE"; fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

NO_HW_CURSORS=$(hyprctl getoption cursor:no_hardware_cursors -j | jq -r '.int // empty') || true
if [[ $NO_HW_CURSORS =~ ^[0-9]+$ ]] && set_no_hw_cursors 0; then CURSOR_CHANGED=true; fi

if ! nixos-capture-region "$MODE" --keep-freeze > "$CAPTURE_RUNTIME/result"; then
  # Escape/cancel is a normal outcome: no new file or clipboard selection.
  exit 0
fi
mapfile -t PICKER_RESULT < "$CAPTURE_RUNTIME/result"
SELECTION=${PICKER_RESULT[1]:-}
[[ $SELECTION =~ ^(-?[0-9]+),(-?[0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]] || exit 1

if [[ $PROCESSING == copy ]]; then
  # The clipboard owner outlives this script and must not retain its lock.
  grim -g "$SELECTION" - | wl-copy --type image/png 9>&-
  exit 0
fi

if [[ $PROCESSING == ocr || $PROCESSING == qr ]]; then
  EXTRACT_FILE=$(mktemp "$CAPTURE_RUNTIME/extract.XXXXXX.png")
  FILEPATH=$EXTRACT_FILE
else
  SCREENSHOT_DIR=${NIXOS_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}
  mkdir -p "$SCREENSHOT_DIR"
  FILEPATH=$(mktemp "$SCREENSHOT_DIR/screenshot-$(date +'%Y-%m-%d_%H-%M-%S')-XXXXXX.png")
fi
if ! grim -g "$SELECTION" "$FILEPATH"; then
  rm -f "$FILEPATH"
  notify-send "Screenshot failed" "The selected area could not be captured." || true
  exit 1
fi

# End the freeze before handing off to clipboard/notification/editor tools.
nixos-capture-region --cancel
if [[ $CURSOR_CHANGED == true ]]; then
  set_no_hw_cursors "$NO_HW_CURSORS" || true
  CURSOR_CHANGED=false
fi

if [[ $PROCESSING == ocr || $PROCESSING == qr ]]; then
  CLIPBOARD_ARGS=(--type 'text/plain;charset=utf-8')
  if [[ $PROCESSING == ocr ]]; then
    TITLE="Screen text"
    EMPTY_MESSAGE="No text was found in the selected area."
    if ! TEXT=$(tesseract "$FILEPATH" stdout -l eng+fra+chi_tra --psm 6); then
      notify-send "$TITLE extraction failed" "The selected area could not be processed." || true
      exit 1
    fi
  else
    TITLE="QR code"
    EMPTY_MESSAGE="No QR code was found in the selected area."
    # QR payloads may contain credentials: never log or display their contents.
    CLIPBOARD_ARGS=(--sensitive "${CLIPBOARD_ARGS[@]}")
    STATUS=0
    TEXT=$(zbarimg --quiet --raw --set disable --set qrcode.enable "$FILEPATH" 2>/dev/null) || STATUS=$?
    if ((STATUS != 0 && STATUS != 4)); then
      notify-send "$TITLE decoding failed" "The selected area could not be processed." || true
      exit 1
    fi
  fi
  if [[ -z ${TEXT//[[:space:]]/} ]]; then
    notify-send "$TITLE" "$EMPTY_MESSAGE" || true
    exit 0
  fi
  if ! printf '%s' "$TEXT" | wl-copy "${CLIPBOARD_ARGS[@]}" 9>&-; then
    notify-send "$TITLE" "The clipboard is unavailable." || true
    exit 1
  fi
  notify-send "$TITLE copied" "The result is ready to paste." || true
  exit 0
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nixos-capture"
mkdir -p "$STATE_DIR"
printf '%s\n' "$FILEPATH" > "$STATE_DIR/latest.tmp"
mv -f "$STATE_DIR/latest.tmp" "$STATE_DIR/latest"
printf '%s\n' "$FILEPATH"

if [[ $PROCESSING == slurp ]]; then
  if ! wl-copy --type image/png 9>&- < "$FILEPATH"; then
    notify-send "Screenshot saved; clipboard unavailable" "$FILEPATH" || true
    exit 1
  fi
  # Do not let this long-lived listener inherit the capture lock.
  nixos-capture-notify "$FILEPATH" 9>&- >/dev/null 2>&1 &
fi
