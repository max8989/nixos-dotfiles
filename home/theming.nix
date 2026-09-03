{ pkgs, ... }:
let
  # Exact Kvantum counterpart of the GTK theme below, so both toolkits land on
  # the same Mocha/blue palette. The nixpkgs default is frappe, hence the
  # override; it installs share/Kvantum/catppuccin-mocha-blue.
  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    variant = "mocha";
    accent = "blue";
  };
in
{
  # Cursor — the Hyprland exec-once sets `catppuccin-frappe-dark-cursors`.
  home.pointerCursor = {
    name = "catppuccin-frappe-dark-cursors";
    package = pkgs.catppuccin-cursors.frappeDark;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-blue-standard";
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "blue" ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # Qt theming. Everything that looked unstyled — Dolphin, Okular, Kate,
  # Gwenview, Ark, Filelight — is Qt6; the GTK apps were always fine.
  #
  # Neither "gtk" nor "gtk3" could ever have worked here. Home Manager turns
  # both into QT_QPA_PLATFORMTHEME=gtk3, and nixpkgs' Qt6 qtbase ships no gtk3
  # platform-theme plugin, so Qt found nothing to load and fell back to bare
  # Fusion with no icon theme — small icons, wrong colours, default font.
  # HM's "qtct" shortcut has the mirror-image bug: it sets
  # QT_QPA_PLATFORMTHEME=qt5ct, but qt6ct only ships
  # lib/qt-6/plugins/platformthemes/libqt6ct.so, which Qt6 resolves from the
  # literal string "qt6ct". platformTheme.name is free-form and is written to
  # the env var verbatim when it is not one of HM's aliases, so naming the
  # plugin directly is what actually makes it load. The package list has to be
  # explicit for the same reason — HM only auto-detects packages for its own
  # known names.
  qt = {
    enable = true;

    platformTheme = {
      name = "qt6ct";
      package = with pkgs; [
        qt6Packages.qt6ct
        libsForQt5.qt5ct
      ];
    };

    # Kvantum draws the widgets (sets QT_STYLE_OVERRIDE and pulls the Qt5/Qt6
    # style plugins).
    style.name = "kvantum";
    kvantum = {
      # Required: qt.kvantum has its own enable flag, defaulting to false.
      # Without it the theme is never written to ~/.config/Kvantum and the
      # style silently falls back to Kvantum's generic default.
      enable = true;
      themes = [ catppuccinKvantum ];
      settings.General.theme = "catppuccin-mocha-blue";
    };

    # qt6ct supplies what Kvantum does not: the icon set and the UI fonts.
    # Fonts must be quoted strings here. Figtree and CaskaydiaCove are the
    # ones already installed in hosts/desktop.nix — plain "Noto Sans" is not
    # (only the CJK variants are), so it would silently fall back.
    # standard_dialogs routes file pickers through the existing xdg portal, so
    # Qt apps get the same file chooser as everything else.
    qt6ctSettings = {
      Appearance = {
        style = "kvantum";
        icon_theme = "Papirus-Dark";
        standard_dialogs = "xdgdesktopportal";
      };
      Fonts = {
        general = ''"Figtree,11"'';
        fixed = ''"CaskaydiaCove Nerd Font Mono,11"'';
      };
    };
    qt5ctSettings = {
      Appearance = {
        style = "kvantum";
        icon_theme = "Papirus-Dark";
        standard_dialogs = "xdgdesktopportal";
      };
      Fonts = {
        general = ''"Figtree,11"'';
        fixed = ''"CaskaydiaCove Nerd Font Mono,11"'';
      };
    };
  };
}
