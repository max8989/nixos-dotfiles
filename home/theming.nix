{ pkgs, lib, ... }:
let
  palette = import ./omarchy-palette.nix;
  rgb =
    color:
    lib.concatStringsSep "," (
      map (offset: toString (lib.fromHexString (builtins.substring offset 2 color))) [
        1
        3
        5
      ]
    );
  kdeColors =
    background: foreground:
    lib.mapAttrs (_: rgb) {
      BackgroundNormal = background;
      BackgroundAlternate = palette.surface;
      ForegroundNormal = foreground;
      ForegroundInactive = palette.muted;
      ForegroundActive = palette.accent;
      ForegroundLink = palette.teal;
      ForegroundVisited = palette.lavender;
      ForegroundNegative = palette.urgent;
      ForegroundNeutral = palette.warning;
      ForegroundPositive = palette.green;
      DecorationFocus = palette.accent;
      DecorationHover = palette.green;
    };
  kdeScheme = {
    # On qt6ct, KColorSchemeManager otherwise substitutes Breeze based on the
    # portal's light/dark hint. This shared default also reaches KDE apps.
    UiSettings.ColorScheme = palette.name;
    General = {
      Name = palette.name;
      ColorScheme = palette.name;
    };
    "Colors:View" = kdeColors palette.background palette.text;
    "Colors:Window" = kdeColors palette.base palette.text;
    "Colors:Button" = kdeColors palette.surface palette.text;
    "Colors:Selection" = kdeColors palette.selection palette.brightText;
    "Colors:Tooltip" = kdeColors palette.surface palette.text;
    "Colors:Complementary" = kdeColors palette.base palette.text;
    "Colors:Header" = kdeColors palette.background palette.text;
    KDE.contrast = 4;
    Icons.Theme = "Yaru-magenta";
  };
  # QPalette roles in Qt's enum order, including PlaceholderText and Accent.
  qtColors =
    text:
    lib.concatStringsSep ", " (
      map (color: "#ff" + lib.removePrefix "#" color) [
        text
        palette.surface
        palette.raised
        palette.border
        palette.background
        palette.border
        text
        palette.text
        text
        palette.background
        palette.base
        palette.background
        palette.selection
        palette.brightText
        palette.teal
        palette.lavender
        palette.surface
        text
        palette.surface
        text
        palette.muted
        palette.accent
      ]
    );
  qtScheme = pkgs.writeText "tokyo-night-qt.colors" (
    lib.generators.toINI { } {
      ColorScheme = {
        active_colors = qtColors palette.text;
        inactive_colors = qtColors palette.text;
        disabled_colors = qtColors palette.dim;
      };
    }
  );
  # GTK follows the captured Adwaita dark preference. Preserve the working Qt
  # widget integration and recolor its complete Kvantum assets to Tokyo Night.
  baseKvantum = pkgs.catppuccin-kvantum.override {
    variant = "mocha";
    accent = "blue";
  };
  colorMap = pkgs.writeText "tokyo-night-colors.json" (
    builtins.toJSON {
      "#1e1e2e" = palette.base;
      "#181825" = palette.background;
      "#11111b" = palette.darkest;
      "#313244" = palette.surface;
      "#45475a" = palette.raised;
      "#585b70" = palette.border;
      "#6c7086" = palette.dim;
      "#7f849c" = palette.dim;
      "#9399b2" = palette.muted;
      "#a6adc8" = palette.muted;
      "#bac2de" = palette.brightText;
      "#cdd6f4" = palette.text;
      "#89b4fa" = palette.accent;
      "#97bbf9" = palette.teal;
      "#b4befe" = palette.accent;
      "#74c7ec" = palette.blue;
      "#89dceb" = palette.teal;
      "#94e2d5" = palette.teal;
      "#a6e3a1" = palette.green;
      "#f9e2af" = palette.yellow;
      "#fab387" = palette.warning;
      "#f38ba8" = palette.urgent;
      "#eba0ac" = palette.urgent;
      "#cba6f7" = palette.lavender;
      "#f5c2e7" = palette.lavender;
      "#f2cdcd" = palette.brightText;
      "#f5e0dc" = palette.text;
    }
  );
  tokyoKvantum =
    pkgs.runCommand "tokyo-night-kvantum-theme" { nativeBuildInputs = [ pkgs.python3 ]; }
      ''
        mkdir -p "$out/share/Kvantum/${palette.name}"
        cp ${baseKvantum}/share/Kvantum/catppuccin-mocha-blue/catppuccin-mocha-blue.svg "$out/share/Kvantum/${palette.name}/${palette.name}.svg"
        cp ${baseKvantum}/share/Kvantum/catppuccin-mocha-blue/catppuccin-mocha-blue.kvconfig "$out/share/Kvantum/${palette.name}/${palette.name}.kvconfig"
        chmod -R u+w "$out"
        python3 ${./files/scripts/recolor-theme.py} "$out" ${colorMap} Catppuccin-Mocha-Blue ${palette.name}
      '';

in
{
  # Cursor — the Hyprland exec-once sets `catppuccin-frappe-dark-cursors`.
  home.pointerCursor = {
    enable = true;
    name = "catppuccin-frappe-dark-cursors";
    package = pkgs.catppuccin-cursors.frappeDark;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  gtk = {
    enable = true;
    colorScheme = "dark";
    font = {
      name = "Figtree";
      size = 11;
    };
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Yaru-magenta";
      package = pkgs.yaru-theme;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    accent-color = "blue";
  };

  # KDE's KColorScheme reads kdeglobals independently of the widget style.
  xdg.configFile."kdeglobals".text = lib.generators.toINI { } kdeScheme;
  xdg.dataFile."color-schemes/${palette.name}.colors".text = lib.generators.toINI { } kdeScheme;

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
      themes = [ tokyoKvantum ];
      settings.General.theme = palette.name;
    };

    # qt6ct supplies what Kvantum does not: the icon set and the UI fonts.
    # Fonts must be quoted strings here. Figtree and JetBrainsMono are the
    # ones already installed in hosts/desktop.nix — plain "Noto Sans" is not
    # (only the CJK variants are), so it would silently fall back.
    # standard_dialogs routes file pickers through the existing xdg portal, so
    # Qt apps get the same file chooser as everything else.
    qt6ctSettings = {
      Appearance = {
        style = "kvantum";
        custom_palette = true;
        color_scheme_path = "${qtScheme}";
        icon_theme = "Yaru-magenta";
        standard_dialogs = "xdgdesktopportal";
      };
      Fonts = {
        general = ''"Figtree,11"'';
        fixed = ''"JetBrainsMono Nerd Font,11"'';
      };
    };
    qt5ctSettings = {
      Appearance = {
        style = "kvantum";
        custom_palette = true;
        color_scheme_path = "${qtScheme}";
        icon_theme = "Yaru-magenta";
        standard_dialogs = "xdgdesktopportal";
      };
      Fonts = {
        general = ''"Figtree,11"'';
        fixed = ''"JetBrainsMono Nerd Font,11"'';
      };
    };
  };
}
