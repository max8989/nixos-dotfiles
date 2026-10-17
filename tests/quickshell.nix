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
        node ${./fingerprint-model.mjs} ${../home/files/quickshell/lock/FingerprintModel.js}
        python3 ${./fingerprint-helper.py} ${../home/files/scripts/desktop-fingerprint.sh}
        python3 ${./quickshell-settings.py} ${../home/files/scripts/quickshell-settings.py}
        luac -p ${../home/files/hypr/hyprland.lua} ${../home/files/hypr/keybindings.lua} ${../home/files/hypr/capture_bindings.lua}
        luac -p ${home.xdg.configFile."hypr/shell_commands.lua".source}
        lua ${./capture-bindings.lua} ${../home/files/hypr/capture_bindings.lua}
        mkdir -p "$out"
        cp lint.json "$out/"
      '';
  shell-integration =
    assert home.programs.quickshell.enable;
    assert home.home.sessionVariables.EDITOR == "nvim";
    assert home.home.sessionVariables.VISUAL == "nvim";
    assert !home.programs.waybar.enable;
    assert !home.services.swaync.enable;
    assert !home.programs.hyprlock.enable;
    assert !home.programs.wofi.enable;
    assert !server.programs.quickshell.enable;
    assert desktop.security.pam.services.quickshell.enable;
    assert !desktop.security.pam.services.quickshell.fprintAuth;
    assert !desktop.security.pam.services.quickshell-fingerprint.unixAuth;
    assert desktop.security.pam.services.quickshell-fingerprint.fprintAuth;
    assert desktop.security.pam.services.sudo.fprintAuth;
    assert desktop.security.pam.services.polkit-1.fprintAuth;
    assert !self.nixosConfigurations.homeserver.config.services.fprintd.enable;
    assert home.programs.kitty.font.name == "JetBrainsMono Nerd Font";
    assert home.programs.kitty.font.size == 9;
    assert home.programs.btop.settings.color_theme == "active";
    assert home.programs.fzf.colors == { };
    assert home.programs.starship.settings == { };
    assert server.programs.starship.settings.palette == "jade";
    assert server.programs.fzf.colors.bg == "#0c191e";
    assert !server.programs.btop.enable;
    assert !(builtins.hasAttr "thinkpad-x1-carbon-g7" self.nixosConfigurations);
    pkgs.runCommand "quickshell-integration-check"
      {
        nativeBuildInputs = [
          pkgs.jq
          pkgs.lua
          pkgs.bash
          pkgs.util-linux
          pkgs.glib
          pkgs.python3
          home.programs.starship.package
          home.programs.kitty.package
        ];
      }
      ''
        test -f ${bundle}/generated.json
        test -x ${pkgs.quickshell}/bin/quickshell
        test -x ${pkgs.quickshell}/bin/qs
        jq -e '
          (.themes | keys) == ["catppuccin", "catppuccin-latte", "flexoki-light", "gruvbox", "nord", "osaka-jade", "tokyo-night", "white"] and
          .themes["tokyo-night"].background == "#1a1b26" and
          .themes["catppuccin-latte"].mode == "light" and
          .themes["flexoki-light"].mode == "light" and
          .themes["flexoki-light"].background == "#FFFCF0" and
          .themes.white.mode == "light" and
          .themes.white.background == "#ffffff" and
          .themes["osaka-jade"].background == "#111c18" and
          .themes.catppuccin.background == "#1e1e2e" and
          .themes.gruvbox.background == "#282828" and
          .themes.nord.background == "#2e3440"
        ' ${bundle}/generated.json
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
        test "$(readlink ${
          home.xdg.configFile."starship.toml".source
        })" = "${home.localTheme.currentDir}/starship.toml"
        # Keep the same config path across switches, as an already open shell does.
        export STARSHIP_CONFIG="$TMPDIR/starship.toml"
        ln -s "$DESKTOP_THEME_STATE/current/starship.toml" "$STARSHIP_CONFIG"
        themeScript=${../home/files/scripts/desktop-theme.sh}
        test "$(bash "$themeScript" current)" = tokyo-night
        test "$(bash "$themeScript" list)" = $'tokyo-night\ncatppuccin-latte\nflexoki-light\nwhite\ncatppuccin\ngruvbox\nnord\nosaka-jade'
        while IFS= read -r theme; do
          test -s "$DESKTOP_THEME_ROOT/$theme/wallpaper.png"
          luac -p "$DESKTOP_THEME_ROOT/$theme/hypr-theme.lua"
          bash "$themeScript" set "$theme"
          test "$(bash "$themeScript" current)" = "$theme"
          test "$(readlink "$DESKTOP_THEME_STATE/current")" = "$DESKTOP_THEME_ROOT/$theme"
          bash "$themeScript" reconcile
          test "$(bash "$themeScript" current)" = "$theme"
          starship module directory --path "$TMPDIR" > "$TMPDIR/directory-prompt"
          python3 - "$STARSHIP_CONFIG" "$TMPDIR/directory-prompt" <<'PY'
        import sys
        import tomllib
        from pathlib import Path

        config = tomllib.loads(Path(sys.argv[1]).read_text())
        colors = config["palettes"][config["palette"]]
        prompt = Path(sys.argv[2]).read_text()
        for key, code in [("s2", 48), ("cyan", 38)]:
            color = colors[key].removeprefix("#")
            rgb = ";".join(str(int(color[i:i + 2], 16)) for i in (0, 2, 4))
            assert f"{code};2;{rgb}" in prompt, f"Stale {key} prompt color for {config['palette']}"
        PY
        done < <(bash "$themeScript" list)
        # Preserve Osaka Jade's distinct normal/bright yellows from upstream.
        grep -Fx 'color3 #459451' "$DESKTOP_THEME_ROOT/osaka-jade/kitty.conf"
        grep -Fx 'color11 #E5C736' "$DESKTOP_THEME_ROOT/osaka-jade/kitty.conf"
        grep -Fx 'theme[main_bg]="#111c18"' "$DESKTOP_THEME_ROOT/osaka-jade/btop.theme"
        test "$(readlink ${
          home.xdg.configFile."kitty/dark-theme.auto.conf".source
        })" = "${home.localTheme.stateDir}/kitty.conf"
        kitty +runpy 'import runpy, sys; path = sys.argv.pop(1); runpy.run_path(path, run_name="__main__")' ${./desktop-theme-kitty.py} "$themeScript"
        if bash "$themeScript" set unknown; then exit 1; fi
        if bash "$themeScript" set ../; then exit 1; fi
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
