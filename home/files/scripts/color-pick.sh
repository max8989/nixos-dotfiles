#!/usr/bin/env bash
# Pick a screen color using the shared capture lock and cancellation workflow.
set -euo pipefail
umask 077

if [[ $# == 1 && ( $1 == --help || $1 == -h ) ]]; then
  echo "Usage: nixos-color-pick"
  exit 0
fi
if (($# != 0)); then
  echo "Usage: nixos-color-pick" >&2
  exit 2
fi

CAPTURE_RUNTIME="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nixos-capture-$UID"
mkdir -p "$CAPTURE_RUNTIME"
exec 9> "$CAPTURE_RUNTIME/capture.lock"
if ! flock -n 9; then
  nixos-capture-region --cancel
  exit 0
fi

RESULT=$(mktemp "$CAPTURE_RUNTIME/color.XXXXXX")
cleanup() {
  nixos-capture-region --cancel || true
  rm -f "$RESULT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

hyprpicker --format hex --no-fancy --render-inactive > "$RESULT" &
PICKER_PID=$!
printf '%s\n' "$PICKER_PID" > "$CAPTURE_RUNTIME/freeze.pid"
STATUS=0
wait "$PICKER_PID" || STATUS=$?
rm -f "$CAPTURE_RUNTIME/freeze.pid"
# Escape or a second capture action cancels without changing the clipboard.
if ((STATUS == 2 || STATUS == 143)); then exit 0; fi
if ((STATUS != 0)); then
  notify-send "Color picker failed" "The screen color could not be picked." || true
  exit 1
fi
# A picker terminated by the shared cancellation helper can exit successfully
# without producing a selection.
[[ -s $RESULT ]] || exit 0
COLOR=$(cat "$RESULT")
if [[ ! $COLOR =~ ^#[[:xdigit:]]{6}$ ]]; then
  notify-send "Color picker failed" "The picker did not return a valid hex color." || true
  exit 1
fi
if ! printf '%s' "$COLOR" | wl-copy --type 'text/plain;charset=utf-8' 9>&-; then
  notify-send "Color picker" "The clipboard is unavailable." || true
  exit 1
fi
notify-send "Color copied" "$COLOR" || true
