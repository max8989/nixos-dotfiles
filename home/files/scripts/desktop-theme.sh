#!/usr/bin/env bash
# Runtime half of the Nix-built desktop themes. The bundle is immutable; only
# the selected name and current link live in XDG state.
set -euo pipefail

theme_root=${DESKTOP_THEME_ROOT:?}
state_dir=${DESKTOP_THEME_STATE:?}
selected_file="$state_dir/selected"
current_link="$state_dir/current"

usage() {
  echo 'Usage: desktop-theme list|current|set <tokyo-night|catppuccin-latte>|reconcile' >&2
  exit 2
}

valid_theme() {
  case "$1" in
    tokyo-night|catppuccin-latte) [[ -d "$theme_root/$1" ]] ;;
    *) return 1 ;;
  esac
}

current_name() {
  local name
  name=$(cat "$selected_file" 2>/dev/null || true)
  if valid_theme "$name"; then
    printf '%s\n' "$name"
  else
    printf 'tokyo-night\n'
  fi
}

apply_session() {
  local name=$1 wallpaper="$theme_root/$1/wallpaper.png" mode gtk_theme icon_theme monitor pid

  if [[ $name == catppuccin-latte ]]; then
    mode=prefer-light
    gtk_theme=Adwaita
    icon_theme=Yaru-blue
  else
    mode=prefer-dark
    gtk_theme=Adwaita-dark
    icon_theme=Yaru-magenta
  fi

  # Omarchy uses these same GNOME settings for GTK and the appearance portal.
  if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    gsettings set org.gnome.desktop.interface color-scheme "$mode"
    gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"
    gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"
    fcitx5-remote --check -r >/dev/null 2>&1 || true
  fi

  if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload >/dev/null 2>&1 || true
    # Reload existing Kitty instances too, including those opened before
    # Home Manager installed the automatic light/dark theme files.
    while IFS= read -r pid; do
      [[ $pid =~ ^[0-9]+$ ]] || continue
      kill -USR1 "$pid" 2>/dev/null || true
    done < <(hyprctl -j clients 2>/dev/null | jq -r '.[] | select(.class == "kitty" or .initialClass == "kitty") | .pid' 2>/dev/null | sort -u || true)
    systemctl --user try-restart hyprshell.service >/dev/null 2>&1 || true
    while IFS= read -r monitor; do
      [[ -n $monitor ]] || continue
      hyprctl hyprpaper wallpaper "$monitor, $wallpaper" >/dev/null 2>&1 || true
    done < <(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
  fi

  quickshell ipc --config desktop call theme set "$name" >/dev/null 2>&1 || true
}

select_theme() {
  local name=$1 announce=$2 temp
  valid_theme "$name" || { echo "Unknown desktop theme: $name" >&2; exit 2; }

  umask 077
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  exec 9>"$state_dir/.lock"
  flock 9

  temp="$state_dir/.current.$$"
  ln -s "$theme_root/$name" "$temp"
  mv -Tf "$temp" "$current_link"
  temp="$state_dir/.selected.$$"
  printf '%s\n' "$name" > "$temp"
  mv -f "$temp" "$selected_file"
  flock -u 9

  apply_session "$name"
  if [[ $announce == yes ]]; then
    printf '%s\n' "$name"
    notify-send -t 2000 "Desktop theme: $name" 2>/dev/null || true
  fi
}

case "${1:-}" in
  list)
    printf 'tokyo-night\ncatppuccin-latte\n'
    ;;
  current)
    current_name
    ;;
  set)
    [[ $# == 2 ]] || usage
    select_theme "$2" yes
    ;;
  reconcile)
    [[ $# == 1 ]] || usage
    select_theme "$(current_name)" no
    ;;
  *) usage ;;
esac
