{
  config,
  pkgs,
  lib,
  inputs,
  username,
  osConfig,
  ...
}:
let
  palette = import ./omarchy-palette.nix;
  capture = import ./capture-tools.nix { inherit pkgs lib inputs; };
  hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  settings = {
    theme = {
      background = palette.background;
      solid = palette.background;
      surface = palette.surface;
      text = palette.text;
      dim = palette.muted;
      blue = palette.blue;
      accent = palette.accent;
      success = palette.green;
      warning = palette.warning;
      urgent = palette.urgent;
      border = palette.accent;
      font = "JetBrainsMono Nerd Font";
      uiFont = "JetBrainsMono Nerd Font";
      fontSize = 12;
      radius = 12;
    }
    // import ./omarchy-shell-style.nix { inherit palette; };
    bar = {
      height = 26;
      margin = 0;
      sideMargin = 0;
    };
    features = {
      bar = true;
      osd = true;
      notifications = true;
      menus = true;
      lock = true;
      polkit = true;
    };
    user = username;
    timeZone = osConfig.time.timeZone;
    paths = {
      home = config.home.homeDirectory;
      dotfiles = "${config.home.homeDirectory}/repos/nixos-dotfiles";
      screenshot = lib.getExe capture.screenshot;
      editScreenshot = lib.getExe capture.edit;
      screenRecord = "${config.xdg.configHome}/scripts/screen_record.sh";
      todo = "${config.home.homeDirectory}/Documents/obsidian/00 Home/00 Todos.md";
      vault = "obsidian";
      todoNote = "00 Home/00 Todos";
      homeNote = "00 Home/Home";
      phrases = "${./files/quickshell/assets/phrases_zh.txt}";
      vim = "${./files/quickshell/assets/vim.txt}";
      lazyvim = "${./files/quickshell/assets/lazyvim.txt}";
    };
    bin = {
      quickshell = lib.getExe pkgs.quickshell;
      hyprctl = "${hyprland}/bin/hyprctl";
      brightnessctl = lib.getExe pkgs.brightnessctl;
      kitty = lib.getExe pkgs.kitty;
      btop = lib.getExe pkgs.btop;
      cliphist = lib.getExe pkgs.cliphist;
      clipboard = lib.getExe clipboard;
      clipboardThumbs = lib.getExe clipboardThumbs;
      xdgOpen = "${pkgs.xdg-utils}/bin/xdg-open";
      systemctl = "${pkgs.systemd}/bin/systemctl";
      loginctl = "${pkgs.systemd}/bin/loginctl";
      notifySend = "${pkgs.libnotify}/bin/notify-send";
      nmtui = "${pkgs.networkmanager}/bin/nmtui";
      bluetooth = "${pkgs.blueman}/bin/blueman-manager";
      editor = lib.getExe pkgs.zed-editor;
      inputMethod = "${pkgs.fcitx5}/bin/fcitx5-remote";
      curl = lib.getExe pkgs.curl;
      grim = lib.getExe pkgs.grim;
      remove = "${pkgs.coreutils}/bin/rm";
      settings = lib.getExe settingsHelper;
    };
  };
  settingsHelper = pkgs.writeScriptBin "quickshell-settings" (
    builtins.replaceStrings
      [ "@python@" "@nmcli@" "@hyprctl@" ]
      [ "${pkgs.python3}/bin/python3" "${pkgs.networkmanager}/bin/nmcli" "${hyprland}/bin/hyprctl" ]
      (builtins.readFile ./files/scripts/quickshell-settings.py)
  );
  clipboard = pkgs.writeShellApplication {
    name = "quickshell-clipboard";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.coreutils
    ];
    text = ''
      # cliphist 0.7 treats a newline as part of a bare ID. Pass the numeric
      # argument directly and keep binary data out of shell/QML strings.
      [[ "$#" -eq 1 && "$1" =~ ^[0-9]+$ ]] || exit 1
      umask 077
      clipboard_file=$(mktemp "''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/quickshell-clipboard.XXXXXX")
      trap 'rm -f -- "$clipboard_file"' EXIT
      # Decode completely before claiming the selection: a stale history ID
      # must not clear the user's current clipboard.
      cliphist decode "$1" > "$clipboard_file"
      wl-copy < "$clipboard_file"
    '';
  };
  # Decode image history entries into a private runtime cache so the
  # clipboard menu can show thumbnails. Prints "<id>\t<path>" per image.
  clipboardThumbs = pkgs.writeShellApplication {
    name = "quickshell-clipboard-thumbs";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.coreutils
    ];
    text = ''
      umask 077
      cache="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/quickshell-clipboard-thumbs"
      mkdir -p -- "$cache"
      declare -A keep=()
      for id in "$@"; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        keep["$id"]=1
        file="$cache/$id"
        if [[ ! -s "$file" ]]; then
          if ! cliphist decode "$id" > "$file.tmp"; then
            rm -f -- "$file.tmp"
            continue
          fi
          mv -f -- "$file.tmp" "$file"
        fi
        printf '%s\t%s\n' "$id" "$file"
      done
      # Drop thumbnails whose entries left the history.
      for file in "$cache"/*; do
        [[ -e "$file" ]] || continue
        name=''${file##*/}
        [[ -n "''${keep[$name]:-}" ]] || rm -f -- "$file"
      done
    '';
  };
  generated = pkgs.writeText "quickshell-generated.json" (builtins.toJSON settings);
  bundle = pkgs.runCommand "quickshell-desktop" { } ''
    mkdir -p "$out"
    cp -r ${./files/quickshell}/. "$out/"
    cp ${generated} "$out/generated.json"
  '';
  development = pkgs.writeShellApplication {
    name = "quickshell-dev";
    runtimeInputs = [
      pkgs.quickshell
      pkgs.coreutils
    ];
    text = ''
      source_dir="''${1:-$PWD}/home/files/quickshell"
      test -f "$source_dir/shell.qml" || { echo "Pass the repository directory" >&2; exit 1; }
      export QS_SETTINGS=${generated}
      export TZ=${lib.escapeShellArg osConfig.time.timeZone}
      export QS_DEV=1 QS_PREVIEW=1 QS_NO_RELOAD_POPUP=1 QT_QUICK_CONTROLS_STYLE=Basic
      export QS_STATE_DIR="''${XDG_RUNTIME_DIR:-/tmp}/quickshell-preview-$UID"
      mkdir -p "$QS_STATE_DIR"
      exec quickshell --path "$source_dir/shell.qml" --no-duplicate
    '';
  };
in
{
  programs.quickshell = {
    enable = true;
    configs.desktop = bundle;
    activeConfig = "desktop";
    systemd.enable = true;
    systemd.target = "graphical-session.target";
  };
  systemd.user.services.quickshell = {
    Unit = {
      After = [ "hyprsunset.service" ];
      PartOf = [
        "graphical-session.target"
        "tray.target"
      ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      # Quickshell 0.3.1 selects its network backend only once. During a rebuild
      # the user service can start before the system NetworkManager service.
      # Bound the wait and allow failure so networking cannot prevent locking.
      ExecStartPre = "-${lib.getExe settingsHelper} network-ready";
      ExecStart = lib.mkForce "${lib.getExe pkgs.quickshell} --config desktop --no-color";
      Environment = [
        "QT_QUICK_CONTROLS_STYLE=Basic"
        "TZ=${osConfig.time.timeZone}"
        "QS_SETTINGS=${bundle}/generated.json"
      ];
      # Keep application preferences outside Quickshell's config-name aliases.
      StateDirectory = "quickshell-desktop";
      StateDirectoryMode = "0700";
      RestartSec = 2;
      UMask = "0077";
      StandardOutput = "journal";
      StandardError = "journal";
    };
    Install.WantedBy = [ "tray.target" ];
  };
  # QS_SETTINGS includes the bundle path so every QML generation changes the
  # unit and triggers a restart. Launch and IPC must both use the config name:
  # Quickshell 0.3.1 hashes a symlink path differently from its store target.
  home.packages = [ development ];
}
