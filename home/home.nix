{
  inputs,
  pkgs,
  lib,
  username,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./kitty.nix
    ./shell.nix
    ./desktop.nix
    ./scripts.nix
    ./theming.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11"; # match system.stateVersion

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  ##########################################################################
  ## Runtime packages — every binary the configs/keybindings/scripts invoke.
  ## On NixOS scripts can't assume a global PATH, so anything referenced must
  ## be here.
  ##########################################################################
  home.packages =
    with pkgs;
    [
      # --- core desktop apps (from keybindings.conf) ---
      kitty
      nautilus
      zed-editor # `zed` editor binary
      btop

      # --- launchers / menus ---
      rofi # rofi-wayland was merged into rofi
      wofi

      # --- clipboard ---
      cliphist
      wl-clipboard # wl-copy / wl-paste

      # --- wayland utils / media ---
      playerctl
      brightnessctl # hypridle.conf
      kanata # caps-lock vim nav, launched from exec-once

      # --- screenshots / recording (scripts/screenshot.sh, screen_record.sh) ---
      hyprshot
      grim
      slurp
      wf-recorder
      swappy

      # --- script + waybar-module dependencies ---
      jq
      yad
      libnotify # notify-send
      bluez # bluetoothctl (bluetooth-menu.sh)
      pavucontrol
      (python3.withPackages (ps: with ps; [ requests ])) # rss-summarize.py
      curl
    ]
    ++ [
      # Zen Browser from its flake (no nixpkgs package).
      inputs.zen-browser.packages.${system}.default
    ];

  # NOTE: `hyprwat` (audio device selector, bound to SUPER+F12 and the waybar
  # pulseaudio on-click) is AUR-only and not in nixpkgs. Until packaged, that
  # bind is dead; `pavucontrol` / `wpctl` cover it. See README "Known gaps".
}
