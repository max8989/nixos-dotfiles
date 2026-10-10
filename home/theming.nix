{ config, pkgs, lib, ... }:
let
  palette = config.localTheme.palettes.tokyo-night;
  active = name: config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/${name}";

  # Preserve the exact Tokyo Night Kvantum recolor used before switching.
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
  tokyoKvantum = pkgs.runCommand "tokyo-night-kvantum-theme" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    mkdir -p "$out/share/Kvantum/${palette.name}"
    cp ${baseKvantum}/share/Kvantum/catppuccin-mocha-blue/catppuccin-mocha-blue.svg "$out/share/Kvantum/${palette.name}/${palette.name}.svg"
    cp ${baseKvantum}/share/Kvantum/catppuccin-mocha-blue/catppuccin-mocha-blue.kvconfig "$out/share/Kvantum/${palette.name}/${palette.name}.kvconfig"
    chmod -R u+w "$out"
    python3 ${./files/scripts/recolor-theme.py} "$out" ${colorMap} Catppuccin-Mocha-Blue ${palette.name}
  '';
  latteKvantum = pkgs.catppuccin-kvantum.override {
    variant = "latte";
    accent = "blue";
  };
in
{
  home.pointerCursor = {
    enable = true;
    name = "catppuccin-frappe-dark-cursors";
    package = pkgs.catppuccin-cursors.frappeDark;
    size = 24;
    hyprcursor.enable = true;
  };

  home.packages = [
    pkgs.gnome-themes-extra
    pkgs.yaru-theme
  ];

  # Home Manager links these to a stable XDG state path. The switcher changes
  # only the state link, so both themes stay reproducible in the Nix store.
  xdg.configFile = {
    "gtk-3.0/settings.ini".source = lib.mkForce (active "gtk3-settings.ini");
    "gtk-4.0/settings.ini".source = lib.mkForce (active "gtk4-settings.ini");
    "gtk-3.0/gtk.css".source = lib.mkForce (active "gtk.css");
    "kdeglobals".source = active "kdeglobals";
    "qt6ct/qt6ct.conf".source = lib.mkForce (active "qt6ct.conf");
    "qt5ct/qt5ct.conf".source = lib.mkForce (active "qt5ct.conf");
    "Kvantum/kvantum.kvconfig".source = lib.mkForce (active "kvantum.kvconfig");
  };
  xdg.dataFile = {
    "color-schemes/Tokyo-Night.colors".source = "${config.localTheme.themeDirs.tokyo-night}/kdeglobals";
    "color-schemes/Catppuccin-Latte.colors".source = "${config.localTheme.themeDirs.catppuccin-latte}/kdeglobals";
  };

  # qt6ct is the actual platform-theme plugin; Kvantum draws the widgets.
  qt = {
    enable = true;
    platformTheme = {
      name = "qt6ct";
      package = with pkgs; [
        qt6Packages.qt6ct
        libsForQt5.qt5ct
      ];
    };
    style.name = "kvantum";
    kvantum = {
      enable = true;
      themes = [ tokyoKvantum latteKvantum ];
    };
  };
}
