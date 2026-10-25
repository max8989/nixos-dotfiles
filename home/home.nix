{
  inputs,
  pkgs,
  username,
  ...
}:
let
  # Fabric does not support Invoke 3 yet. Pin it throughout Azure CLI's
  # package set so Fabric and Paramiko share one compatible version.
  # Remove once https://github.com/fabric/fabric/issues/2376 is resolved.
  azureCliPkgs = pkgs.extend (
    _: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_: pythonPrev: {
          invoke = pythonPrev.invoke.overridePythonAttrs (_: {
            version = "2.2.1";
            src = pkgs.fetchPypi {
              pname = "invoke";
              version = "2.2.1";
              hash = "sha256-UVv0m0pIkyt5sCRZA0jaIvOcSULf+ZGtH7i4uuob5wc=";
            };
          });
        })
      ];
    }
  );
in
{
  imports = [
    ./theme.nix
    ./hyprland.nix
    ./dictation.nix
    ./quickshell.nix
    ./kitty.nix
    ./cli.nix
    ./shell.nix
    ./desktop.nix
    ./fcitx5.nix
    ./scripts.nix
    ./theming.nix
    ./zen.nix
    ./superfile.nix
    ./omarchy.nix
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
  home.packages = with pkgs; [
    # --- core desktop apps (from keybindings.conf) ---
    kitty
    # Main GUI file manager — set as the XDG default for inode/directory in
    # desktop.nix. kio-extras supplies the extra KIO protocols and the
    # thumbnailers Dolphin has no built-in equivalent for; without it a
    # non-Plasma session gets a working but thumbnail-less Dolphin.
    kdePackages.dolphin
    kdePackages.kio-extras
    nautilus # kept as a GTK fallback; nothing defaults to it any more

    # PDF reader and GUI text editor. Both are KDE rather than GNOME so they
    # share Dolphin's Qt stack — no second GTK4/libadwaita closure, and
    # Dolphin's "Open With" and service menus pick them up natively. The GNOME
    # equivalents are `papers` and `gnome-text-editor` if you prefer them.
    kdePackages.okular
    kdePackages.kate

    # Image viewers, deliberately both: gwenview is the double-click default
    # (Qt, thumbnail browser, basic editing), imv is the tiny Wayland-native
    # one with vim keys for opening a file straight from a shell or keybind.
    kdePackages.gwenview
    imv
    # Archive manager — also what gives Dolphin its right-click
    # extract/compress entries; without it archives are terminal-only.
    kdePackages.ark
    # Second PDF reader, vim-keybound, kept alongside Okular: Okular for
    # annotating and forms, zathura for reading. The nixpkgs `zathura` attr is
    # the with-plugins wrapper and already bundles libpdf-mupdf.so, so no
    # separate backend package is needed.
    zathura
    # Visual disk usage (Qt counterpart of baobab).
    kdePackages.filelight
    qalculate-gtk
    zed-editor # `zed` editor binary

    # --- clipboard ---
    cliphist
    wl-clipboard # wl-copy / wl-paste

    # --- wayland utils / media ---
    playerctl
    brightnessctl # hypridle.conf
    kanata # caps-lock vim nav, launched from exec-once

    # --- screenshots / recording (scripts/screenshot.sh, screen_record.sh) ---
    wf-recorder

    # --- independent script dependencies ---
    yad
    libnotify # notify-send
    pavucontrol
    (python3.withPackages (ps: with ps; [ requests ])) # rss-summarize.py
    # Shared CLI dependencies (jq, curl, psmisc) come from cli.nix.
    xdg-utils # xdg-open — desktop file/URI actions

    # --- GUI apps (migrated from arch-linux-setup install_packages.sh) ---
    firefox
    google-chrome
    libreoffice
    vlc
    snapshot # GNOME Camera — photos and videos through PipeWire
    cameractrls-gtk4 # Webcam exposure, white balance, and sharpness controls
    discord
    slack
    spotify
    obsidian
    qbittorrent
    localsend
    impression # bootable-USB writer (Etcher is not in nixpkgs)
    solaar # Logitech device manager
    blueman # bluetooth GUI (service enabled in common.nix)
    nwg-look # GTK theme settings
    tor-browser
    zoom-us
    ticktick

    # --- games ---
    # The guide's Windows osu!stable, with a patched low-latency runtime.
    (inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.osu-stable.override {
      useGameMode = false; # This desktop does not run a GameMode daemon.
    })

    # --- desktop-specific terminal tools ---
    # General CLI tools and core development runtimes come from cli.nix.
    # superfile (TUI file manager, SUPER+E) is installed from superfile.nix —
    # it comes from the upstream flake input, not nixpkgs.
    alsa-utils # alsamixer / aplay (was `alsa-utils`)
    nchat # terminal chat client (Telegram, WhatsApp)

    # --- dev block ---
    awscli2
    azureCliPkgs.azure-cli
    (
      with dotnetCorePackages;
      combinePackages [
        sdk_9_0
        sdk_10_0
        aspnetcore_9_0
        aspnetcore_10_0
      ]
    )
    supabase-cli
    postgresql # psql / pg_dump client tools only — no server (that's services.postgresql)
    insomnia
    claude-code
    codex
    # --- claude-config (~/repos/claude-config) dependencies ---
    # install.sh uses gh (provided by cli.nix) to fetch the MCP server
    # binaries into that repository's bin/ directory.
    # jetbrains.rider
    # jetbrains.datagrip
  ];

  # Shell menus, sound, notifications and locking are owned by quickshell.nix.
}
