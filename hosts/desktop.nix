###############################################################################
# Desktop-only system configuration — imported by graphical hosts (the
# ThinkPads) IN ADDITION to ../common.nix. Headless hosts (homeserver) must
# not import this file.
#
# Everything here exists to serve the Hyprland session: the compositor itself,
# login manager, audio, input, portals, fonts, and the laptop peripherals the
# desktop shell and retained utilities talk to.
###############################################################################
{
  inputs,
  pkgs,
  username,
  ...
}:
{
  imports = [
    # Share the VPN tunnel with a guest over Wi-Fi AP or Thunderbolt.
    ./vpn-hotspot.nix
  ];

  ##########################################################################
  ## Nix — Hyprland flake is not built by Hydra / cache.nixos.org; pull its
  ## prebuilt binaries from the official Cachix instead of compiling locally.
  ## Valid only because we do NOT override hyprland's nixpkgs input (see
  ## flake.nix).
  ##########################################################################
  nix.settings.substituters = [ "https://hyprland.cachix.org" ];
  nix.settings.trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
  ];
  # bitwarden-desktop currently bundles an EOL Electron that nixpkgs flags as
  # insecure. Permit just that version; drop this once bitwarden bumps Electron.
  nixpkgs.config.permittedInsecurePackages = [ "electron-39.8.10" ];

  ##########################################################################
  ## Input methods — Chinese input via fcitx5. Ctrl+Space cycles us -> ca ->
  ## pinyin (the cycle-input script in home/hyprland.nix); Ctrl+Alt+Space
  ## toggles fcitx5 alone. Both binds live in the Hyprland keybindings.
  ##########################################################################
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
    # Native Wayland IM protocol instead of exporting GTK_IM_MODULE, which
    # fcitx5's "Wayland Diagnose" warns about on Wayland compositors.
    fcitx5.waylandFrontend = true;
    # Profile, popup theme and Traditional (Taiwan) output: home/fcitx5.nix.
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
  ##
  ## `start-hyprland`, NOT the bare `Hyprland` binary: since 0.5x the binary
  ## is only the compositor, and the wrapper is what sets up the session
  ## (env/XDG vars, dbus). Launching `Hyprland` directly still works but
  ## paints the "started without start-hyprland" warning banner on every
  ## login. It is also what the package's own hyprland.desktop entry execs.
  ##########################################################################
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
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
  users.users.${username}.extraGroups = [ "uinput" ];

  ##########################################################################
  ## Desktop / laptop peripherals & services
  ##########################################################################
  # ThinkPad fingerprint reader. Enroll with `fprintd-enroll`.
  services.fprintd.enable = true;
  # Separate conversations allow password entry while fingerprint auth waits.
  security.pam.services.quickshell.fprintAuth = false;
  security.pam.services.quickshell-fingerprint = {
    unixAuth = false;
    fprintAuth = true;
  };
  # Power profiles and battery data are consumed by Quickshell over D-Bus.
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  # Brightness control without root (hypridle / Quickshell via brightnessctl).
  services.udev.packages = [ pkgs.brightnessctl ];
  # Bluetooth devices and the advanced pairing UI.
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # GUI bluetooth manager
  # Removable media. Without udisks2 nothing mounts a USB stick — it shows up in
  # `lsblk` and then just sits there, since there is no desktop environment here
  # to do it. udisks2 is the DBus service that does the mounting (under
  # /run/media/$USER/<label>); polkit (common.nix) is what lets the logged-in
  # user drive it without sudo. gvfs is the GIO/userspace-VFS layer nautilus
  # needs to show the drive in its sidebar and to reach mtp:// / smb:// /
  # trash://. The actual auto-mount-on-plug is `services.udiskie` in
  # home/desktop.nix.
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  # Flatpak (for apps not packaged in nixpkgs). Add remotes manually post-install,
  # e.g. `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`.
  services.flatpak.enable = true;

  ##########################################################################
  ## Fonts
  ##########################################################################
  fonts = {
    fontDir.enable = true;
    packages = with pkgs; [
      nerd-fonts.caskaydia-cove
      nerd-fonts.jetbrains-mono # Kitty and Omarchy-styled shell
      figtree # native GTK/Qt applications
      noto-fonts # captured Hyprland groupbar font (Noto Sans)
      font-awesome # general icon glyphs
      # CJK — lock screen phrases and fcitx5 Chinese input candidates.
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      source-han-sans # Adobe CJK sans (was adobe-source-han-sans-otc)
      source-han-serif # Adobe CJK serif (was adobe-source-han-serif-otc)
    ];
    fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];
  };
}
