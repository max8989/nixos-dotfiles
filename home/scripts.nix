{
  pkgs,
  lib,
  inputs,
  config,
  ...
}:
let
  capture = import ./capture-tools.nix { inherit pkgs lib inputs; };
in
{
  # Independent screenshot, recording and RSS tools. Desktop state and battery
  # alerts are handled inside Quickshell.
  xdg.configFile."scripts".source = ./files/scripts;
  home.packages = [
    capture.region
    capture.screenshot
    capture.edit
  ];
  xdg.configFile."swappy/config".text = lib.generators.toINI { } {
    Default = {
      save_dir = "${config.home.homeDirectory}/Pictures/Screenshots";
      save_filename_format = "screenshot-edited-%Y%m%d-%H%M%S.png";
      show_panel = true;
      early_exit = true;
      custom_color = "rgba(122,162,247,1)";
    };
  };
}
