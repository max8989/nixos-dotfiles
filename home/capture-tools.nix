{
  pkgs,
  lib,
  inputs,
}:
let
  hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  region = pkgs.writeShellApplication {
    name = "nixos-capture-region";
    runtimeInputs = [
      hyprland
      pkgs.jq
      pkgs.slurp
      pkgs.hyprpicker
      pkgs.coreutils
    ];
    text = builtins.readFile ./files/scripts/capture-region.sh;
  };
  notify = pkgs.writeShellApplication {
    name = "nixos-capture-notify";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.swappy
    ];
    text = ''
      [[ $# == 1 && -f $1 ]] || exit 1
      # Keep the action listener outside the capture process: notification
      # outages/timeouts cannot hold a frozen display or fail a saved capture.
      action=$(notify-send --app-name Screenshot --icon "$1" \
        --hint "string:image-path:$1" --action "edit=Edit" --wait \
        "Screenshot saved to file and clipboard" \
        "Edit with Super + Alt + , or click Edit") || exit 0
      if [[ $action == edit ]]; then exec swappy -f "$1"; fi
    '';
  };
  screenshot = pkgs.writeShellApplication {
    name = "nixos-screenshot";
    runtimeInputs = [
      region
      notify
      hyprland
      pkgs.grim
      pkgs.jq
      pkgs.wl-clipboard
      pkgs.coreutils
      pkgs.util-linux
      pkgs.libnotify
    ];
    text = builtins.readFile ./files/scripts/screenshot.sh;
  };
  edit = pkgs.writeShellApplication {
    name = "nixos-screenshot-edit";
    runtimeInputs = [
      pkgs.swappy
      pkgs.libnotify
    ];
    text = ''
      latest="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-capture/latest"
      if [[ ! -s $latest ]]; then
        notify-send "No screenshot to edit" "Take a screenshot first."
        exit 0
      fi
      IFS= read -r file < "$latest"
      if [[ ! -f $file ]]; then
        notify-send "Screenshot no longer exists" "$file"
        exit 0
      fi
      exec swappy -f "$file"
    '';
  };
in
{
  inherit
    region
    screenshot
    edit
    notify
    ;
}
