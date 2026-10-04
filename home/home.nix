{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./hyprland.nix
    ./quickshell.nix
    ./kitty.nix
    ./shell.nix
    ./desktop.nix
    ./scripts.nix
    ./theming.nix
    ./zen.nix
    ./superfile.nix
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
    btop

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

    # --- independent script dependencies ---
    jq
    yad
    libnotify # notify-send
    pavucontrol
    (python3.withPackages (ps: with ps; [ requests ])) # rss-summarize.py
    curl
    # NixOS has no global /usr/bin, so these must be requested explicitly —
    # each is called by name from a script or keybind and would otherwise
    # fail silently at runtime.
    psmisc # process inspection and recording helpers
    xdg-utils # xdg-open — desktop file/URI actions

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
    # superfile (TUI file manager, SUPER+E) is installed from superfile.nix —
    # it comes from the upstream flake input, not nixpkgs.
    neovim
    bun
    lazygit
    dnsutils # dig / nslookup (was `bind`)
    alsa-utils # alsamixer / aplay (was `alsa-utils`)
    zip
    stow
    nchat # terminal chat client (Telegram, WhatsApp)

    # --- dev block ---
    docker-compose
    lazydocker
    awscli2
    azure-cli
    uv
    nodejs
    yarn
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
    vscode
    insomnia
    claude-code
    codex
    # --- claude-config (~/repos/claude-config) dependencies ---
    # Only gh is declared here; its install.sh fetches the MCP server
    # binaries (github-mcp-server, mcp-server-git) itself into the repo's
    # bin/, and gh is what performs that release download.
    gh
    jetbrains.rider
    jetbrains.datagrip
  ];

  # Shell menus, sound, notifications and locking are owned by quickshell.nix.
}
