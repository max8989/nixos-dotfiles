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
    assert home.programs.kitty.settings.background == "#1a1b26";
    assert home.programs.btop.settings.color_theme == "omarchy-tokyo-night";
    assert home.programs.fzf.colors.bg == "#1a1b26";
    assert server.programs.fzf.colors.bg == "#0c191e";
    assert !server.programs.btop.enable;
    assert !(builtins.hasAttr "thinkpad-x1-carbon-g7" self.nixosConfigurations);
    pkgs.runCommand "quickshell-integration-check" { } ''
      test -f ${bundle}/generated.json
      test -x ${pkgs.quickshell}/bin/quickshell
      test -x ${pkgs.quickshell}/bin/qs
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
