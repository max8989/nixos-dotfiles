{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  palettes = import ./theme-data.nix;
  stateDir = "${config.xdg.stateHome}/desktop-theme";
  currentDir = "${stateDir}/current";
  toINI = lib.generators.toINI { };
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
    p: background: foreground:
    lib.mapAttrs (_: rgb) {
      BackgroundNormal = background;
      BackgroundAlternate = p.surface;
      ForegroundNormal = foreground;
      ForegroundInactive = p.muted;
      ForegroundActive = p.accent;
      ForegroundLink = p.teal;
      ForegroundVisited = p.lavender;
      ForegroundNegative = p.urgent;
      ForegroundNeutral = p.warning;
      ForegroundPositive = p.green;
      DecorationFocus = p.accent;
      DecorationHover = p.green;
    };
  kdeScheme = p: {
    UiSettings.ColorScheme = p.name;
    General = {
      Name = p.name;
      ColorScheme = p.name;
    };
    "Colors:View" = kdeColors p p.background p.text;
    "Colors:Window" = kdeColors p p.base p.text;
    "Colors:Button" = kdeColors p p.surface p.text;
    "Colors:Selection" = kdeColors p p.selection p.brightText;
    "Colors:Tooltip" = kdeColors p p.surface p.text;
    "Colors:Complementary" = kdeColors p p.base p.text;
    "Colors:Header" = kdeColors p p.background p.text;
    KDE.contrast = 4;
    Icons.Theme = p.iconTheme;
  };
  qtColors =
    p: text:
    lib.concatStringsSep ", " (
      map (color: "#ff" + lib.removePrefix "#" color) [
        text
        p.surface
        p.raised
        p.border
        p.background
        p.border
        text
        p.text
        text
        p.background
        p.base
        p.background
        p.selection
        p.brightText
        p.teal
        p.lavender
        p.surface
        text
        p.surface
        text
        p.muted
        p.accent
      ]
    );
  qtScheme = p: toINI {
    ColorScheme = {
      active_colors = qtColors p p.text;
      inactive_colors = qtColors p p.text;
      disabled_colors = qtColors p p.dim;
    };
  };
  qtctSettings = p: toINI {
    Appearance = {
      style = "kvantum";
      custom_palette = true;
      color_scheme_path = "${currentDir}/qt.colors";
      icon_theme = p.iconTheme;
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      general = ''"Figtree,11"'';
      fixed = ''"JetBrainsMono Nerd Font,11"'';
    };
    Applications = { };
  };
  gtkSettings = p: version: ''
    [Settings]
    gtk-application-prefer-dark-theme=${if p.mode == "dark" then "true" else "false"}
    gtk-cursor-theme-name=catppuccin-frappe-dark-cursors
    gtk-cursor-theme-size=24
    gtk-font-name=Figtree 11
    gtk-icon-theme-name=${p.iconTheme}
    ${if version == 3 then "gtk-theme-name=${if p.mode == "dark" then "Adwaita-dark" else "Adwaita"}" else "gtk-interface-color-scheme=${p.mode}"}
  '';
  yadCss = p: ''
    #yad-dialog-window {
      background-color: ${p.background};
      color: ${p.text};
      font-family: "Figtree";
      font-size: 11pt;
    }
    #yad-dialog-window label { color: ${p.text}; }
    #yad-dialog-window entry {
      background-image: none;
      background-color: ${p.surface};
      color: ${p.brightText};
      border: 1px solid ${p.border};
      border-radius: 9px;
      padding: 8px 10px;
      box-shadow: none;
    }
    #yad-dialog-window entry:focus { border-color: ${p.accent}; }
    #yad-dialog-window entry selection {
      background-color: ${p.selection};
      color: ${p.brightText};
    }
    #yad-dialog-window button {
      background-image: none;
      background-color: ${p.surface};
      color: ${p.text};
      border: 1px solid ${p.border};
      border-radius: 9px;
      padding: 6px 14px;
      text-shadow: none;
      box-shadow: none;
    }
    #yad-dialog-window button:hover,
    #yad-dialog-window button:focus {
      background-color: ${p.raised};
      border-color: ${p.accent};
      color: ${p.brightText};
    }
    #yad-dialog-window button:active { background-color: ${p.selection}; }
  '';
  kittyColors =
    p:
    let
      colors = lib.concatStringsSep "\n" (lib.imap0 (i: color: "color${toString i} ${color}") p.ansi);
    in
    ''
      background ${p.background}
      foreground ${p.text}
      cursor ${p.brightText}
      cursor_text_color ${p.background}
      selection_background ${p.selection}
      selection_foreground ${p.brightText}
      url_color ${p.teal}
      active_border_color ${p.accent}
      inactive_border_color ${p.border}
      active_tab_background ${p.accent}
      active_tab_foreground ${p.background}
      inactive_tab_background ${p.background}
      inactive_tab_foreground ${p.muted}
      ${colors}
    '';
  fzfOptions = p: ''
    --color=bg:${p.background},bg+:${p.surface},fg:${p.muted},fg+:${p.text},hl:${p.accent},hl+:${p.accent},border:${p.border},prompt:${p.accent},pointer:${p.accent},marker:${p.green},spinner:${p.teal},info:${p.muted}
  '';
  starshipSettings = p: (lib.importTOML ./starship.toml) // {
    palette = p.name;
    palettes.${p.name} = {
      s1 = p.base;
      s2 = p.surface;
      text = p.text;
      muted = p.muted;
      dim = p.dim;
      cyan = p.accent;
      blue = p.blue;
      green = p.green;
      red = p.urgent;
      amber = p.warning;
    };
  };
  fcitxSettings = p: lib.generators.toINIWithGlobalSection { } {
    globalSection = {
      Theme = p.fcitxTheme;
      DarkTheme = p.fcitxTheme;
      UseDarkTheme = "False";
      UseAccentColor = "False";
      "Vertical Candidate List" = "False";
      Font = "Noto Sans CJK TC 15";
      MenuFont = "Figtree 12";
      TrayFont = "Figtree Medium 11";
      PerScreenDPI = "True";
      EnableFractionalScale = "True";
    };
    sections = { };
  };
  btopTemplate = builtins.readFile ./files/omarchy/btop.theme.tpl;
  latteColors = builtins.fromTOML (builtins.readFile ./files/omarchy/catppuccin-latte-colors.toml);
  latteBtop = lib.replaceStrings
    (map (key: "{{ ${key} }}") (builtins.attrNames latteColors))
    (map (key: latteColors.${key}) (builtins.attrNames latteColors))
    btopTemplate;
  mkTheme =
    id: p:
    let
      themeFiles = {
        "hypr-theme.lua" = "return " + lib.generators.toLua { } (builtins.removeAttrs p [ "wallpaper" ]);
        "hyprshell.css" = ''
          :root {
            --border-color: ${p.border};
            --border-color-active: ${p.accent};
            --bg-color: ${p.base};
            --bg-color-hover: ${p.raised};
            --bg-window-color: ${p.background};
            --text-color: ${p.text};
            --border-radius: 14px;
            --border-size: 2px;
            --border-style: solid;
          }
          .window { font-family: Figtree; }
        '';
        "kitty.conf" = kittyColors p;
        "qt.colors" = qtScheme p;
        "qt6ct.conf" = qtctSettings p;
        "qt5ct.conf" = qtctSettings p;
        "kvantum.kvconfig" = toINI {
          General.theme = if id == "tokyo-night" then p.name else "catppuccin-latte-blue";
        };
        "kdeglobals" = toINI (kdeScheme p);
        "gtk3-settings.ini" = gtkSettings p 3;
        "gtk4-settings.ini" = gtkSettings p 4;
        "gtk.css" = yadCss p;
        "fcitx-classicui.conf" = fcitxSettings p;
        "vscode-settings.json" = builtins.toJSON { "workbench.colorTheme" = p.vscodeTheme; };
        "starship.toml" = (pkgs.formats.toml { }).generate "${id}-starship.toml" (starshipSettings p);
        "fzf-options" = fzfOptions p;
        "superfile.toml" = (pkgs.formats.toml { }).generate "${id}-superfile.toml" (
          import ./superfile-theme.nix { palette = p; }
        );
        "btop.theme" = if id == "tokyo-night" then ./files/omarchy/btop.theme else latteBtop;
      };
      copyFiles = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: content:
          let
            source = if builtins.isPath content || lib.isDerivation content then content else pkgs.writeText "${id}-${name}" content;
          in
          ''cp ${source} "$out/${name}"''
        ) themeFiles
      );
    in
    pkgs.runCommand "desktop-theme-${id}" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      mkdir -p "$out"
      ${copyFiles}
      ${if id == "tokyo-night" then "cp ${p.wallpaper} \"$out/wallpaper.png\"" else "magick ${p.wallpaper} \"$out/wallpaper.png\""}
    '';
  themeDirs = lib.mapAttrs mkTheme palettes;
  themeRoot = pkgs.runCommand "desktop-themes" { } ''
    mkdir -p "$out"
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: path: ''ln -s ${path} "$out/${id}"'') themeDirs)}
  '';
  hyprland = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  switcher = pkgs.writeShellApplication {
    name = "desktop-theme";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
      pkgs.jq
      pkgs.glib
      pkgs.fcitx5
      pkgs.quickshell
      pkgs.libnotify
      pkgs.systemd
      hyprland
    ];
    text = ''
      export DESKTOP_THEME_ROOT=${lib.escapeShellArg "${themeRoot}"}
      export DESKTOP_THEME_STATE=${lib.escapeShellArg stateDir}
      # Shell applications do not inherit the schema search paths that GTK
      # wrappers add. Supply the GNOME interface schema explicitly so apps
      # receive the same light/dark preference as the desktop shell.
      export GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas
      ${builtins.readFile ./files/scripts/desktop-theme.sh}
    '';
  };
in
{
  options.localTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    description = "Generated runtime desktop theme assets and state paths.";
  };

  config = {
    localTheme = {
      inherit palettes stateDir currentDir themeDirs themeRoot switcher;
    };
    home.packages = [ switcher ];
    home.activation.desktopTheme = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${lib.getExe switcher} reconcile
    '';
  };
}
