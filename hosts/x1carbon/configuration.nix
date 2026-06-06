{
  inputs,
  pkgs,
  lib,
  username,
  fullName,
  hostname,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  ##########################################################################
  ## Boot / kernel
  ##########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  ##########################################################################
  ## Nix / flakes
  ##########################################################################
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Hyprland flake is not built by Hydra / cache.nixos.org — pull its prebuilt
  # binaries from the official Cachix instead of compiling locally. Valid only
  # because we do NOT override hyprland's nixpkgs input (see flake.nix).
  nix.settings.substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];
  nixpkgs.config.allowUnfree = true;

  ##########################################################################
  ## Networking / locale / time
  ##########################################################################
  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "America/Toronto"; # TODO: confirm timezone
  i18n.defaultLocale = "en_CA.UTF-8";

  # Chinese input — fcitx5. The us/ca layout toggle (Ctrl+Space) and the fcitx5
  # toggle (Ctrl+Alt+Space) live in the Hyprland keybindings.
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
  };

  ##########################################################################
  ## Hyprland (compositor) — pinned to the Hyprland flake input so the
  ## compositor and its xdg portal stay in sync.
  ##########################################################################
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Portals + screen sharing.
  xdg.portal = {
    enable = true;
    # hyprland portal comes from programs.hyprland; add gtk for file pickers.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  ##########################################################################
  ## Login — greetd + tuigreet launching Hyprland.
  ##########################################################################
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      user = "greeter";
    };
  };

  ##########################################################################
  ## Audio — PipeWire
  ##########################################################################
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  ##########################################################################
  ## Kanata (caps-lock vim nav). Runs as the user from Hyprland exec-once; it
  ## needs /dev/uinput access, provided here.
  ##########################################################################
  hardware.uinput.enable = true;

  ##########################################################################
  ## Misc system services
  ##########################################################################
  security.polkit.enable = true;
  services.dbus.enable = true;
  # ThinkPad fingerprint reader (7th gen). Enroll with `fprintd-enroll`.
  services.fprintd.enable = true;
  # Power profile switcher — backs waybar's `power-profiles-daemon` module.
  services.power-profiles-daemon.enable = true;
  # Brightness control without root (hypridle / swayosd via brightnessctl).
  services.udev.packages = [ pkgs.brightnessctl ];
  # Bluetooth (waybar bluetooth-menu.sh / bluetoothctl).
  hardware.bluetooth.enable = true;

  ##########################################################################
  ## Fonts
  ##########################################################################
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.caskaydia-cove # kitty (CaskaydiaCove Nerd Font Mono)
      nerd-fonts.jetbrains-mono # waybar style.css (JetBrainsMono Nerd Font)
      figtree # rofi (Figtree)
      # CJK — hyprlock phrases_zh.txt + fcitx5 Chinese input candidates.
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];
  };

  ##########################################################################
  ## User
  ##########################################################################
  users.users.${username} = {
    isNormalUser = true;
    description = fullName;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "uinput"
    ];
    shell = pkgs.bash;
  };

  # System-wide packages kept minimal; user software lives in Home Manager.
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # First NixOS generation this config targets. Do not change after install.
  system.stateVersion = "25.11"; # TODO: set to the installer's release
}
