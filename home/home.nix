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
  home.stateVersion = "26.05"; # match system.stateVersion

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
      # NixOS has no global /usr/bin, so these must be requested explicitly —
      # each is called by name from a script or keybind and would otherwise
      # fail silently at runtime.
      psmisc # killall — rofi toggle in keybindings.lua, power-menu.sh
      lm_sensors # sensors — waybar/scripts/cpu-temp.sh
      xdg-utils # xdg-open — scripts/rofi-fb-official.sh
      pulseaudio # pactl — waybar/scripts/volume-control.sh (talks to pipewire-pulse)

      # --- GUI apps (migrated from arch-linux-setup install_packages.sh) ---
      firefox
      google-chrome
      libreoffice-fresh
      vlc
      discord
      slack
      spotify
      bitwarden-desktop
      obsidian
      qbittorrent
      localsend
      solaar # Logitech device manager
      blueman # bluetooth GUI (service enabled in common.nix)
      nwg-look # GTK theme settings

      # --- CLI tools ---
      eza # backs the ls/ll/la/lt aliases in shell.nix
      bat # backs the `cat` alias in shell.nix
      htop
      wget
      fd
      ripgrep
      fastfetch
      yazi
      superfile # TUI file manager (SUPER+E); binary is `superfile`, not `spf`
      neovim
      bun
      lazygit
      dnsutils # dig / nslookup (was `bind`)
      alsa-utils # alsamixer / aplay (was `alsa-utils`)
      zip

      # --- dev block ---
      docker-compose
      lazydocker
      awscli2
      azure-cli
      uv
      (
        with dotnetCorePackages;
        combinePackages [
          sdk_9_0
          aspnetcore_9_0
        ]
      )
      supabase-cli
      vscode
      insomnia
      claude-code
      jetbrains.rider
      jetbrains.datagrip
    ]
    ++ [
      # Zen Browser from its flake (no nixpkgs package).
      inputs.zen-browser.packages.${system}.default
    ];

  # NOTE: `hyprwat` (audio device selector, bound to SUPER+F12 and the waybar
  # pulseaudio on-click) is AUR-only and not in nixpkgs. Until packaged, that
  # bind is dead; `pavucontrol` / `wpctl` cover it. See README "Known gaps".
}
