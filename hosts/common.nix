###############################################################################
# Shared system configuration imported by every host's configuration.nix.
#
# Everything here is host-agnostic. Per-machine bits (filesystems, kernel
# modules, microcode, GPU driver packages) live in each host's own
# hardware-configuration.nix / configuration.nix — NOT here.
###############################################################################
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
  # bitwarden-desktop currently bundles an EOL Electron that nixpkgs flags as
  # insecure. Permit just that version; drop this once bitwarden bumps Electron.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  ##########################################################################
  ## Networking / locale / time
  ##########################################################################
  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  # NetworkManager OpenVPN plugin — import/use .ovpn configs from the applet.
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  # Firewall (mirrors the old Arch ufw setup: deny incoming, allow SSH/HTTP/HTTPS).
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
    ];
  };

  time.timeZone = "America/Toronto";
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
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
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
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
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
  # ThinkPad fingerprint reader. Enroll with `fprintd-enroll`.
  services.fprintd.enable = true;
  # Power profile switcher — backs waybar's `power-profiles-daemon` module.
  services.power-profiles-daemon.enable = true;
  # Brightness control without root (hypridle / swayosd via brightnessctl).
  services.udev.packages = [ pkgs.brightnessctl ];
  # Bluetooth (waybar bluetooth-menu.sh / bluetoothctl).
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # GUI bluetooth manager
  # Flatpak (for apps not packaged in nixpkgs). Add remotes manually post-install,
  # e.g. `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`.
  services.flatpak.enable = true;
  # earlyoom — kill memory hogs before the system locks up under OOM.
  services.earlyoom.enable = true;

  ##########################################################################
  ## Virtualisation — Docker (dev block). User added to the docker group below.
  ##########################################################################
  virtualisation.docker.enable = true;

  ##########################################################################
  ## Fonts
  ##########################################################################
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.caskaydia-cove # kitty (CaskaydiaCove Nerd Font Mono)
      nerd-fonts.jetbrains-mono # waybar style.css (JetBrainsMono Nerd Font)
      figtree # rofi (Figtree)
      font-awesome # icon glyphs (waybar / general)
      # CJK — hyprlock phrases_zh.txt + fcitx5 Chinese input candidates.
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      source-han-sans # Adobe CJK sans (was adobe-source-han-sans-otc)
      source-han-serif # Adobe CJK serif (was adobe-source-han-serif-otc)
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
      "docker"
    ];
    shell = pkgs.bash;
  };

  # System-wide packages kept minimal; user software lives in Home Manager.
  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  # First NixOS generation this config targets. Do not change after install.
  system.stateVersion = "26.05"; # the release first installed; never bump after install
}
