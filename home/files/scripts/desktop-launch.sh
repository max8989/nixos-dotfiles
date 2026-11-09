#!/usr/bin/env bash
# Keep app2unit responsible for desktop-entry expansion and MIME handling.
set -euo pipefail

usage() {
  echo 'Usage: desktop-launch [--important|--normal] [--open] -- <desktop-entry|command|URL|file> [arguments...]' >&2
}

preference=
open=false
while (($#)); do
  case "$1" in
    --important) preference=avoid ;;
    --normal) preference=none ;;
    --open) open=true ;;
    --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) usage; exit 2 ;;
    *) break ;;
  esac
  shift
done
if (($# == 0)); then
  usage
  exit 2
fi

if [[ -z $preference ]]; then
  name=${1##*/}
  name=${name%%:*} # Desktop entry action, e.g. firefox.desktop:new-window.
  name=${name%.desktop}
  case "${name,,}" in
    firefox|google-chrome|com.google.chrome|chrome|chromium|zen|zen-beta|zed|dev.zed.zed|kate|org.kde.kate|kitty|kitty-open|nvim)
      preference=avoid ;;
    *) preference=none ;;
  esac
  # Documents and links opened from the desktop are interactive work too.
  if $open; then preference=avoid; fi
fi

args=(-t scope -s app.slice -p "ManagedOOMPreference=$preference")
if $open; then args+=(-O); fi
exec app2unit "${args[@]}" -- "$@"
