{
  pkgs,
  self,
  system,
  username,
}:
let
  desktop = self.nixosConfigurations.thinkpad-x1-carbon-g12.config;
  home = desktop.home-manager.users.${username};
  server = self.nixosConfigurations.homeserver.config.home-manager.users.${username};
  bundle = self.packages.${system}.quickshell-config;
in
{
  quickshell =
    pkgs.runCommand "quickshell-check"
      {
        nativeBuildInputs = [
          pkgs.qt6.qtdeclarative
          pkgs.python3
          pkgs.nodejs
          pkgs.lua
        ];
      }
      ''
        python3 ${./quickshell-lint.py} ${bundle} ${pkgs.quickshell}/lib/qt-6/qml ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml lint.json
        node ${./quickshell-logic.mjs} ${../home/files/quickshell/Logic.js}
        python3 ${./quickshell-settings.py} ${../home/files/scripts/quickshell-settings.py}
        luac -p ${../home/files/hypr/hyprland.lua} ${../home/files/hypr/keybindings.lua} ${../home/files/hypr/capture_bindings.lua}
        luac -p ${home.xdg.configFile."hypr/shell_commands.lua".source}
        lua ${./capture-bindings.lua} ${../home/files/hypr/capture_bindings.lua}
        mkdir -p "$out"
        cp lint.json "$out/"
      '';
  shell-integration =
    assert home.programs.quickshell.enable;
    assert !home.programs.waybar.enable;
    assert !home.services.swaync.enable;
    assert !home.programs.hyprlock.enable;
    assert !home.programs.wofi.enable;
    assert !server.programs.quickshell.enable;
    assert desktop.security.pam.services.quickshell.enable;
    assert home.programs.kitty.font.name == "JetBrainsMono Nerd Font";
    assert home.programs.kitty.font.size == 9;
    assert home.programs.btop.settings.color_theme == "active";
    assert home.programs.fzf.colors == { };
    assert server.programs.fzf.colors.bg == "#0c191e";
    assert !server.programs.btop.enable;
    assert !(builtins.hasAttr "thinkpad-x1-carbon-g7" self.nixosConfigurations);
    pkgs.runCommand "quickshell-integration-check" { nativeBuildInputs = [ pkgs.jq pkgs.lua pkgs.bash pkgs.util-linux pkgs.glib ]; } ''
      test -f ${bundle}/generated.json
      test -x ${pkgs.quickshell}/bin/quickshell
      test -x ${pkgs.quickshell}/bin/qs
      jq -e '.themes["tokyo-night"].background == "#1a1b26" and .themes["catppuccin-latte"].mode == "light"' ${bundle}/generated.json
      test -s ${home.localTheme.themeDirs.catppuccin-latte}/wallpaper.png
      luac -p ${home.localTheme.themeDirs.tokyo-night}/hypr-theme.lua ${home.localTheme.themeDirs.catppuccin-latte}/hypr-theme.lua
      export DESKTOP_THEME_ROOT=${home.localTheme.themeRoot}
      export DESKTOP_THEME_STATE="$TMPDIR/theme-state"
      # Exercise the actual packaged schema path without changing desktop
      # settings or relying on a login session's schema search paths.
      export GSETTINGS_SCHEMA_DIR=$(sed -n 's/^export GSETTINGS_SCHEMA_DIR=//p' ${pkgs.lib.getExe home.localTheme.switcher})
      test -s "$GSETTINGS_SCHEMA_DIR/gschemas.compiled"
      export GSETTINGS_BACKEND=memory
      export DBUS_SESSION_BUS_ADDRESS="unix:path=$TMPDIR/no-session-bus"
      unset HYPRLAND_INSTANCE_SIGNATURE
      mkdir -p "$TMPDIR/bin"
      printf '#!/bin/sh\nexit 0\n' > "$TMPDIR/bin/quickshell"
      cp "$TMPDIR/bin/quickshell" "$TMPDIR/bin/notify-send"
      chmod +x "$TMPDIR/bin/quickshell" "$TMPDIR/bin/notify-send"
      export PATH="$TMPDIR/bin:$PATH"
      themeScript=${../home/files/scripts/desktop-theme.sh}
      test "$(bash "$themeScript" current)" = tokyo-night
      test "$(bash "$themeScript" list)" = $'tokyo-night\ncatppuccin-latte'
      bash "$themeScript" set catppuccin-latte
      test "$(bash "$themeScript" current)" = catppuccin-latte
      test "$(readlink "$DESKTOP_THEME_STATE/current")" = "$DESKTOP_THEME_ROOT/catppuccin-latte"
      bash "$themeScript" reconcile
      test "$(bash "$themeScript" current)" = catppuccin-latte
      if bash "$themeScript" set unknown; then exit 1; fi
      # A failed appearance update must not report a successful theme switch.
      printf '#!/bin/sh\nexit 1\n' > "$TMPDIR/bin/gsettings"
      chmod +x "$TMPDIR/bin/gsettings"
      if bash "$themeScript" set tokyo-night; then exit 1; fi
      touch "$out"
    '';
  capture =
    pkgs.runCommand "capture-check"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.bash
          pkgs.jq
          pkgs.coreutils
          pkgs.util-linux
        ];
      }
      ''
        python3 ${./capture.py} ${../home/files/scripts}
        touch "$out"
      '';
}
