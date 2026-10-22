#!/usr/bin/env bash
# Runtime half of the Nix-built desktop themes. The bundle is immutable; only
# the selected name, wallpaper choices and current links live in XDG state.
set -euo pipefail

theme_root=${DESKTOP_THEME_ROOT:?}
state_dir=${DESKTOP_THEME_STATE:?}
selected_file="$state_dir/selected"
current_link="$state_dir/current"
wallpaper_dir="$state_dir/wallpapers"
wallpaper_link="$state_dir/wallpaper.png"

usage() {
  echo 'Usage: desktop-theme list|current|set <name>|reconcile' >&2
  echo '       desktop-theme wallpaper current [theme]|set <image> [theme]|reset [theme]' >&2
  echo '       desktop-theme wallpaper list <directory>' >&2
  exit 2
}

valid_theme() {
  [[ $1 =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && -d "$theme_root/$1" ]] &&
    jq -e --arg name "$1" '.themes | has($name)' "$theme_root/catalog.json" >/dev/null
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

lock_state() {
  umask 077
  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  exec 9>"$state_dir/.lock"
  flock 9
}

wallpaper_path() {
  if [[ -s "$wallpaper_dir/$1" ]]; then
    readlink -f -- "$wallpaper_dir/$1"
  else
    printf '%s\n' "$theme_root/$1/wallpaper.png"
  fi
}

list_wallpapers() {
  local directory path
  directory=$(realpath -e -- "$1")
  [[ -d $directory && -r $directory && -x $directory ]] || {
    echo 'Choose a readable directory' >&2
    return 2
  }
  directory=${directory%/}
  shopt -s nullglob
  for path in "$directory"/*; do
    if [[ -d $path ]]; then
      printf 'd%s\0' "$path"
    elif [[ -f $path && -r $path ]]; then
      case ${path,,} in
        *.png|*.jpg|*.jpeg|*.webp|*.bmp) printf 'f%s\0' "$path" ;;
      esac
    fi
  done | jq -Rs '[split("\u0000")[] | select(length > 0) |
    {directory: startswith("d"), path: .[1:]} |
    . + {name: (.path | split("/") | last)}] |
    sort_by([(if .directory then 0 else 1 end), (.name | ascii_downcase)])'
}

publish_wallpaper() {
  local temp="$state_dir/.wallpaper-link.$$"
  ln -s -- "$(wallpaper_path "$1")" "$temp"
  mv -Tf -- "$temp" "$wallpaper_link"
}

apply_wallpaper() {
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || return 0
  local wallpaper monitor
  wallpaper=$(wallpaper_path "$1")
  while IFS= read -r monitor; do
    [[ -n $monitor ]] || continue
    hyprctl hyprpaper wallpaper "$monitor, $wallpaper" >/dev/null 2>&1 || true
  done < <(hyprctl -j monitors 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
}

change_wallpaper() {
  local action=$1 source=$2 name=$3 format digest image temp
  lock_state
  name=${name:-$(current_name)}
  valid_theme "$name" || { echo "Unknown desktop theme: $name" >&2; exit 2; }

  if [[ $action == set ]]; then
    source=$(realpath -e -- "$source")
    [[ -f $source && -r $source ]] || { echo 'Choose a readable image file' >&2; exit 2; }
    case ${source##*.} in
      [pP][nN][gG]) format=png ;;
      [jJ][pP][gG]|[jJ][pP][eE][gG]) format=jpeg ;;
      [wW][eE][bB][pP]) format=webp ;;
      [bB][mM][pP]) format=bmp ;;
      *) echo 'Supported wallpapers: PNG, JPEG, WebP and BMP' >&2; exit 2 ;;
    esac
    # Decode before publishing, and keep our own copy if the source is moved.
    # Explicit raster decoders also keep filenames out of ImageMagick's syntax.
    wallpaper_temp=$(mktemp "$state_dir/.wallpaper.XXXXXXXX")
    trap '[[ -z ${wallpaper_temp:-} ]] || rm -f -- "$wallpaper_temp"' EXIT
    magick "$format:${source}[0]" -auto-orient -strip "png:$wallpaper_temp"
    digest=$(sha256sum -- "$wallpaper_temp")
    digest=${digest%% *}
    mkdir -p "$wallpaper_dir/images"
    image="$wallpaper_dir/images/$digest.png"
    # A different image gets a different path, bypassing wallpaper caches.
    mv -f -- "$wallpaper_temp" "$image"
    wallpaper_temp=""
    temp="$wallpaper_dir/.selected.$$"
    ln -s -- "$image" "$temp"
    mv -Tf -- "$temp" "$wallpaper_dir/$name"
  else
    rm -f -- "$wallpaper_dir/$name"
  fi

  if [[ $name == "$(current_name)" ]]; then
    publish_wallpaper "$name"
    apply_wallpaper "$name"
  fi
  flock -u 9
  wallpaper_path "$name"
  notify-send -t 2000 "Wallpaper saved for $name" 2>/dev/null || true
}

apply_session() {
  local name=$1 mode gtk_theme icon_theme pid

  mode=$(jq -er --arg name "$name" '.themes[$name].mode' "$theme_root/catalog.json")
  icon_theme=$(jq -er --arg name "$name" '.themes[$name].iconTheme' "$theme_root/catalog.json")
  if [[ $mode == light ]]; then
    gtk_theme=Adwaita
  else
    gtk_theme=Adwaita-dark
  fi

  # Omarchy uses these same GNOME settings for GTK and the appearance portal.
  if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"
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
  fi

  apply_wallpaper "$name"
  quickshell ipc --config desktop call theme set "$name" >/dev/null 2>&1 || true
}

select_theme() {
  local name=$1 announce=$2 temp
  valid_theme "$name" || { echo "Unknown desktop theme: $name" >&2; exit 2; }

  lock_state

  # Kitty's automatic theme cache only re-reads files with a newer mtime.
  # Nix store assets share the epoch timestamp, so publish a fresh snapshot
  # before changing the appearance settings and sending the reload signal.
  temp="$state_dir/.kitty.conf.$$"
  cp "$theme_root/$name/kitty.conf" "$temp"
  mv -f "$temp" "$state_dir/kitty.conf"

  temp="$state_dir/.current.$$"
  ln -s "$theme_root/$name" "$temp"
  mv -Tf "$temp" "$current_link"
  temp="$state_dir/.selected.$$"
  printf '%s\n' "$name" > "$temp"
  mv -f "$temp" "$selected_file"
  publish_wallpaper "$name"

  apply_session "$name"
  flock -u 9
  if [[ $announce == yes ]]; then
    printf '%s\n' "$name"
    notify-send -t 2000 "Desktop theme: $name" 2>/dev/null || true
  fi
}

case "${1:-}" in
  list)
    jq -r '.order[]' "$theme_root/catalog.json"
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
  wallpaper)
    case "${2:-}" in
      list)
        [[ $# == 3 ]] || usage
        list_wallpapers "$3"
        ;;
      current)
        [[ $# == 2 || $# == 3 ]] || usage
        name=${3:-$(current_name)}
        valid_theme "$name" || { echo "Unknown desktop theme: $name" >&2; exit 2; }
        wallpaper_path "$name"
        ;;
      set)
        [[ $# == 3 || $# == 4 ]] || usage
        change_wallpaper set "$3" "${4:-}"
        ;;
      reset)
        [[ $# == 2 || $# == 3 ]] || usage
        change_wallpaper reset "" "${3:-}"
        ;;
      *) usage ;;
    esac
    ;;
  *) usage ;;
esac
