{
  config,
  pkgs,
  lib,
  ...
}:
let
  palettes = config.localTheme.palettes;
  active = name: config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/${name}";

  # Reuse the established Kvantum recolor with a matching light/dark base.
  baseKvantum = pkgs.catppuccin-kvantum.override {
    variant = "mocha";
    accent = "blue";
  };
  colorMap =
    id: palette:
    pkgs.writeText "${id}-colors.json" (
      builtins.toJSON (
        if palette.mode == "light" then
          {
            "#eff1f5" = palette.background;
            "#e6e9ef" = palette.base;
            "#dce0e8" = palette.darkest;
            "#ccd0da" = palette.surface;
            "#bcc0cc" = palette.raised;
            "#acb0be" = palette.border;
            "#9ca0b0" = palette.muted;
            "#8c8fa1" = palette.muted;
            "#7c7f93" = palette.dim;
            "#6c6f85" = palette.dim;
            "#5c5f77" = palette.muted;
            "#4c4f69" = palette.text;
            "#1e66f5" = palette.accent;
            "#2762d9" = palette.accent;
            "#3375f5" = palette.blue;
            "#7287fd" = palette.accent;
            "#04a5e5" = palette.blue;
            "#209fb5" = palette.teal;
            "#179299" = palette.teal;
            "#40a02b" = palette.green;
            "#df8e1d" = palette.yellow;
            "#fe640b" = palette.warning;
            "#d20f39" = palette.urgent;
            "#e64553" = palette.urgent;
            "#8839ef" = palette.lavender;
            "#ea76cb" = palette.lavender;
            "#dd7878" = palette.brightText;
            "#dc8a78" = palette.text;
          }
        else
          {
            # Preserve Tokyo Night's original background mapping.
            "#1e1e2e" = if id == "tokyo-night" then palette.base else palette.background;
            "#181825" = if id == "tokyo-night" then palette.background else palette.base;
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
      )
    );
  recoloredKvantum =
    id: palette:
    let
      light = palette.mode == "light";
      base = if light then latteKvantum else baseKvantum;
      variant = if light then "Latte" else "Mocha";
      sourceName = "catppuccin-${lib.toLower variant}-blue";
    in
    pkgs.runCommand "${id}-kvantum-theme" { nativeBuildInputs = [ pkgs.python3 ]; } ''
      mkdir -p "$out/share/Kvantum/${palette.name}"
      cp ${base}/share/Kvantum/${sourceName}/${sourceName}.svg "$out/share/Kvantum/${palette.name}/${palette.name}.svg"
      cp ${base}/share/Kvantum/${sourceName}/${sourceName}.kvconfig "$out/share/Kvantum/${palette.name}/${palette.name}.kvconfig"
      chmod -R u+w "$out"
      python3 ${./files/scripts/recolor-theme.py} "$out" ${colorMap id palette} Catppuccin-${variant}-Blue ${palette.name}
    '';
  latteKvantum = pkgs.catppuccin-kvantum.override {
    variant = "latte";
    accent = "blue";
  };
  kvantumThemes = lib.mapAttrsToList (
    id: palette: if id == "catppuccin-latte" then latteKvantum else recoloredKvantum id palette
  ) palettes;
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
  # only the state link, so all themes stay reproducible in the Nix store.
  xdg.configFile = {
    "gtk-3.0/settings.ini".source = lib.mkForce (active "gtk3-settings.ini");
    "gtk-4.0/settings.ini".source = lib.mkForce (active "gtk4-settings.ini");
    "gtk-3.0/gtk.css".source = lib.mkForce (active "gtk.css");
    "kdeglobals".source = active "kdeglobals";
    "qt6ct/qt6ct.conf".source = lib.mkForce (active "qt6ct.conf");
    "qt5ct/qt5ct.conf".source = lib.mkForce (active "qt5ct.conf");
    "Kvantum/kvantum.kvconfig".source = lib.mkForce (active "kvantum.kvconfig");
  };
  xdg.dataFile = builtins.foldl' (
    files: id:
    files
    // {
      "color-schemes/${palettes.${id}.name}.colors".source = "${
        config.localTheme.themeDirs.${id}
      }/kdeglobals";
    }
  ) { } (builtins.attrNames palettes);

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
      themes = kvantumThemes;
    };
  };
}
