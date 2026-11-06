#!/usr/bin/env bash
# Toggle recording: [fullscreen|region|windows] [none|desktop|microphone].
# --stop never starts a recording; --status prints the owned session as JSON.
set -euo pipefail
umask 077

MODE=${1:-fullscreen}
AUDIO=${2:-none}
case "$MODE" in
  --status|--stop) [[ $# == 1 ]] || exit 2 ;;
  fullscreen|region|windows)
    [[ $# -le 2 ]] || exit 2
    case "$AUDIO" in none|desktop|microphone) ;; *) exit 2 ;; esac
    ;;
  *) echo "Usage: nixos-screen-record [fullscreen|region|windows] [none|desktop|microphone] | --stop | --status" >&2; exit 2 ;;
esac

RUNTIME="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nixos-screen-record-$UID"
STATE="$RUNTIME/state.json"

# A PID alone can be reused after a crash. Check the process start time too.
process_token() {
  local stat
  [[ -r /proc/$1/stat ]] || return 1
  IFS= read -r stat < "/proc/$1/stat" || return 1
  stat=${stat##*) }
  [[ $stat != Z\ * ]] || return 1
  printf '%s\n' "$stat" | cut -d ' ' -f 20
}
read_session() {
  local token
  SESSION=$(cat "$STATE" 2>/dev/null) || return 1
  read -r OWNER token < <(jq -er '[.pid, .token] | @tsv' <<< "$SESSION") || return 1
  [[ $OWNER =~ ^[0-9]+$ && $OWNER -gt 1 && -n $token ]] || return 1
  [[ $(process_token "$OWNER") == "$token" ]]
}
if [[ $MODE == --status ]]; then
  if read_session; then
    jq -c '{active: true, phase, mode, audio, file, startedAt}' <<< "$SESSION"
  else
    printf '{"active":false}\n'
  fi
  exit 0
fi

mkdir -p "$RUNTIME"
exec 9> "$RUNTIME/record.lock"
if ! flock -n 9; then
  if read_session; then kill -TERM "$OWNER" 2>/dev/null || true; fi
  exit 0
fi
[[ $MODE != --stop ]] || exit 0

TOKEN=$(process_token $$)
PHASE=selecting
STARTED=0
FILE=""
SAVED=false
STOP_REQUESTED=false
CHILD_PID=""
CHILD_SIGNAL=TERM
write_state() {
  jq -cn --argjson pid "$$" --arg token "$TOKEN" --arg phase "$PHASE" \
    --arg mode "$MODE" --arg audio "$AUDIO" --arg file "$FILE" --argjson startedAt "$STARTED" \
    '{pid: $pid, token: $token, phase: $phase, mode: $mode, audio: $audio, file: $file, startedAt: $startedAt}' \
    > "$STATE.tmp"
  mv -f "$STATE.tmp" "$STATE"
}
stop_child() {
  if [[ -n $CHILD_PID ]]; then kill -s "$CHILD_SIGNAL" "$CHILD_PID" 2>/dev/null || true; fi
}
cleanup() {
  stop_child
  if [[ -n $CHILD_PID ]]; then wait "$CHILD_PID" 2>/dev/null || true; fi
  if [[ -n $FILE && $SAVED != true ]]; then rm -f -- "$FILE"; fi
  rm -f "$STATE" "$STATE.tmp" "$RUNTIME/selection"
}
request_stop() {
  [[ $STOP_REQUESTED != true ]] || return 0
  STOP_REQUESTED=true
  if [[ $PHASE == recording ]]; then PHASE=stopping; write_state; fi
  stop_child
}
wait_child() {
  local result=0
  wait "$CHILD_PID" || result=$?
  # A trapped signal interrupts wait before the recorder finishes its MP4.
  if [[ $STOP_REQUESTED == true ]]; then
    result=0
    wait "$CHILD_PID" || result=$?
  fi
  CHILD_PID=""
  return "$result"
}
fail() {
  notify-send --app-name "Screen Recording" --icon video-display "Screen recording failed" "$1" || true
  exit 1
}
trap cleanup EXIT
trap request_stop INT TERM
write_state

# Keep frames arriving on static screens too: the recorder's Wayland read
# otherwise waits for damage during shutdown. Limit the saved video to 30 fps.
ARGS=(-D -r 30 -c libx264 -p preset=ultrafast -x yuv420p)
if [[ $AUDIO != none ]]; then
  SOURCE=""
  if [[ $AUDIO == desktop ]]; then
    SINK=$(pactl get-default-sink) || fail "No desktop audio output is available."
    SOURCE=$(pactl --format=json list sinks | jq -er --arg sink "$SINK" \
      '.[] | select(.name == $sink) | .monitor_source | select(type == "string" and length > 0)') || fail "No desktop audio monitor is available."
  else
    SOURCE=$(pactl get-default-source) || fail "No microphone is available."
  fi
  [[ -n $SOURCE ]] || fail "The selected audio source is unavailable."
  ARGS+=("--audio=$SOURCE")
fi

[[ $STOP_REQUESTED != true ]] || exit 0
if [[ $MODE == fullscreen ]]; then
  MONITOR=$(hyprctl monitors -j | jq -er '.[] | select(.focused == true) | .name') || fail "No focused monitor is available."
  ARGS+=(-o "$MONITOR")
else
  # Share the screenshot lock only while selecting, so both tools cannot own
  # the frozen-screen picker simultaneously. The picker releases its freeze.
  CAPTURE_RUNTIME="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/nixos-capture-$UID"
  mkdir -p "$CAPTURE_RUNTIME"
  exec 8> "$CAPTURE_RUNTIME/capture.lock"
  flock -n 8 || fail "Finish the active screenshot selection first."
  [[ $STOP_REQUESTED != true ]] || exit 0
  nixos-capture-region "$MODE" --match-monitor > "$RUNTIME/selection" &
  CHILD_PID=$!
  [[ $STOP_REQUESTED != true ]] || stop_child
  if ! wait_child; then exit 0; fi
  exec 8>&-
  [[ $STOP_REQUESTED != true ]] || exit 0
  IFS= read -r SELECTION < "$RUNTIME/selection"
  if [[ $SELECTION == monitor:* ]]; then
    ARGS+=(-o "${SELECTION#monitor:}")
  elif [[ $SELECTION =~ ^-?[0-9]+,-?[0-9]+[[:space:]][0-9]+x[0-9]+$ ]]; then
    ARGS+=(-g "$SELECTION")
  else
    fail "The selected recording area is invalid."
  fi
fi

[[ $STOP_REQUESTED != true ]] || exit 0
PHASE=countdown
write_state
notify-send --app-name "Screen Recording" --icon video-display --expire-time=3000 \
  "Screen recording starts in 3 seconds" "Press Alt+4 or click the recording indicator to cancel." || true
[[ $STOP_REQUESTED != true ]] || exit 0
sleep 3 &
CHILD_PID=$!
[[ $STOP_REQUESTED != true ]] || stop_child
wait_child || true
[[ $STOP_REQUESTED != true ]] || exit 0

DIRECTORY=${NIXOS_SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}/ScreenRecordings}
mkdir -p "$DIRECTORY"
FILE=$(mktemp "$DIRECTORY/screenrecording-$(date +'%Y-%m-%d_%H-%M-%S')-XXXXXX.mp4")
[[ $STOP_REQUESTED != true ]] || exit 0
CHILD_SIGNAL=INT
wf-recorder "${ARGS[@]}" -y -f "$FILE" </dev/null > "$RUNTIME/recorder.log" 2>&1 &
CHILD_PID=$!
[[ $STOP_REQUESTED != true ]] || stop_child
STARTED=$(date +%s)
PHASE=recording
write_state
RESULT=0
wait_child || RESULT=$?
if [[ $RESULT != 0 || ! -s $FILE ]]; then fail "The recorder could not save the video. Details: $RUNTIME/recorder.log"; fi
SAVED=true
printf '%s\n' "$FILE"
# A notification action listener must not keep the recording lock or pipes.
nixos-screen-record-notify "$FILE" 9>&- >/dev/null 2>&1 &
