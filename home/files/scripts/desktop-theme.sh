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
  echo '       desktop-theme wallpaper library [theme]|import <image>...|select <id> [theme]|delete <id>' >&2
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

store_wallpaper() (
    local source format digest image temp metadata status=imported
    IFS= read -r -d '' source < <(realpath -ze -- "$1") || return 2
    [[ -f $source && -r $source ]] || { echo 'Choose a readable image file' >&2; return 2; }
    case ${source##*.} in
      [pP][nN][gG]) format=png ;;
      [jJ][pP][gG]|[jJ][pP][eE][gG]) format=jpeg ;;
      [wW][eE][bB][pP]) format=webp ;;
      [bB][mM][pP]) format=bmp ;;
      *) echo 'Supported wallpapers: PNG, JPEG, WebP and BMP' >&2; return 2 ;;
    esac
    # Decode before publishing, and keep our own copy if the source is moved.
    # Explicit raster decoders also keep filenames out of ImageMagick's syntax.
    temp=$(mktemp "$state_dir/.wallpaper.XXXXXXXX") || return
    metadata="$temp.json"
    trap 'rm -f -- "$temp" "$metadata"' EXIT
    magick "$format:${source}[0]" -auto-orient -strip "png:$temp" || return
    digest=$(sha256sum -- "$temp") || return
    digest=${digest%% *}
    mkdir -p "$wallpaper_dir/images" || return
    [[ ! -L $wallpaper_dir && ! -L $wallpaper_dir/images ]] || return 2
    image="$wallpaper_dir/images/$digest.png"
    [[ ! -L $image ]] || return 2
    if [[ -s $image ]]; then status=duplicate; fi
    # A different image gets a different path, bypassing wallpaper caches.
    if [[ $status == imported ]]; then
      mv -f -- "$temp" "$image" || return
    fi
    if [[ ! -f $wallpaper_dir/images/$digest.json ]]; then
      jq -n --arg name "${1##*/}" --argjson added "$(date +%s)" \
        '{name: $name, added: $added}' > "$metadata" || return
      mv -f -- "$metadata" "$wallpaper_dir/images/$digest.json" || return
    fi
    jq -n --arg id "$digest" --arg path "$image" --arg status "$status" \
      '{id: $id, path: $path, status: $status}'
)

managed_wallpaper() {
  [[ $1 =~ ^[a-f0-9]{64}$ && ! -L $wallpaper_dir && ! -L $wallpaper_dir/images &&
     -f $wallpaper_dir/images/$1.png && ! -L $wallpaper_dir/images/$1.png ]]
}

wallpaper_references() {
  local name path
  while IFS= read -r name; do
    path=$(wallpaper_path "$name")
    jq -n --arg name "$name" --arg path "$path" '{name: $name, path: $path}'
  done < <(jq -r '.order[]' "$theme_root/catalog.json") | jq -s '.'
}

wallpaper_library() {
  local name=${1:-$(current_name)} image id metadata references
  valid_theme "$name" || { echo "Unknown desktop theme: $name" >&2; return 2; }
  lock_state
  references=$(wallpaper_references)
  shopt -s nullglob
  {
    for image in "$wallpaper_dir/images/"*.png; do
      id=${image##*/}; id=${id%.png}
      managed_wallpaper "$id" || continue
      metadata=$(jq -c 'select(.name | type == "string") | {name, added: (.added | if type == "number" then . else 0 end)}' \
        "$wallpaper_dir/images/$id.json" 2>/dev/null) || metadata=""
      jq -n --arg id "$id" --arg path "$image" --argjson refs "$references" \
        --argjson meta "${metadata:-null}" '{id: $id, path: $path,
          name: ($meta.name // ("Saved wallpaper " + $id[0:8])), added: ($meta.added // 0),
          builtin: false, usedBy: [$refs[] | select(.path == $path) | .name]}'
    done
  } | jq -s --arg current "$(wallpaper_path "$name")" \
      --arg default "$theme_root/$name/wallpaper.png" --arg theme "$name" '
    sort_by([-(.added), .name]) as $images |
    {current: ([$images[] | select(.path == $current) | .id][0] // "default"),
     entries: ([{id: "default", name: "Theme default", path: $default, builtin: true,
       usedBy: (if $current == $default then [$theme] else [] end)}] + $images)}'
}

import_wallpapers() {
  local source result failed=0 results=()
  lock_state
  for source in "$@"; do
    if result=$(store_wallpaper "$source"); then
      results+=("$result")
    else
      failed=1
      results+=("$(jq -n --arg source "$source" \
        '{status: "error", source: $source, error: "Choose a readable PNG, JPEG, WebP or BMP image."}')")
    fi
  done
  printf '%s\n' "${results[@]}" | jq -s '.'
  return "$failed"
}

delete_wallpaper() {
  local id=$1 references name active
  lock_state
  managed_wallpaper "$id" || { echo 'Choose an imported wallpaper ID' >&2; return 2; }
  references=$(wallpaper_references | jq --arg path "$wallpaper_dir/images/$id.png" \
    '[.[] | select(.path == $path) | .name]')
  active=$(current_name)
  while IFS= read -r name; do
    rm -f -- "$wallpaper_dir/$name"
    if [[ $name == "$active" ]]; then
      publish_wallpaper "$name"
      apply_wallpaper "$name"
    fi
  done < <(jq -r '.[]' <<< "$references")
  rm -f -- "$wallpaper_dir/images/$id.png" "$wallpaper_dir/images/$id.json"
  jq -n --argjson themes "$references" '{resetThemes: $themes}'
}

change_wallpaper() {
  local action=$1 source=$2 name=$3 image temp
  lock_state
  name=${name:-$(current_name)}
  valid_theme "$name" || { echo "Unknown desktop theme: $name" >&2; exit 2; }

  if [[ $action == set || $action == select ]]; then
    if [[ $action == set ]]; then
      image=$(store_wallpaper "$source")
      image=$(jq -r '.path' <<< "$image")
    else
      managed_wallpaper "$source" || { echo 'Choose an imported wallpaper ID' >&2; return 2; }
      image="$wallpaper_dir/images/$source.png"
    fi
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
      library)
        [[ $# == 2 || $# == 3 ]] || usage
        wallpaper_library "${3:-}"
        ;;
      import)
        [[ $# -ge 3 ]] || usage
        import_wallpapers "${@:3}"
        ;;
      select)
        [[ $# == 3 || $# == 4 ]] || usage
        change_wallpaper select "$3" "${4:-}"
        ;;
      delete)
        [[ $# == 3 ]] || usage
        delete_wallpaper "$3"
        ;;
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
