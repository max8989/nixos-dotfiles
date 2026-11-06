#!/usr/bin/env bash
# Return a JSON selection; importing and applying are separate gallery actions.
set -euo pipefail
[[ $# == 2 && ( $1 == dialog || $1 == superfile ) ]] || exit 2
mode=$1
folder=$2
if [[ ! -d $folder || ! -r $folder || ! -x $folder ]]; then folder="$HOME"; fi
umask 077
selection_dir=$(mktemp -d "${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/wallpaper-import.XXXXXXXX")
trap 'rm -rf -- "$selection_dir"' EXIT
selection="$selection_dir/selected"
if [[ $mode == superfile ]]; then
  kitty --class wallpaper-import --title 'Import wallpaper — Enter selects, Esc cancels' \
    -e superfile --chooser-file "$selection" "$folder" > "$selection_dir/log" 2>&1
  if [[ -s $selection ]]; then
    # v1.6.0 returns one literal path, without a trailing newline. Never eval it.
    jq -n --rawfile path "$selection" '{paths: [$path], folder: ($path | sub("/[^/]+$"; ""))}'
  else
    printf '{"paths":[]}\n'
  fi
else
  quickshell-wallpaper-dialog "$folder" 2> "$selection_dir/log"
fi
