{ config, pkgs, ... }:
{
  # Desktop-only: the server imports shell.nix but not this module.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "active";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
    };
    themes.active = config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/btop.theme";
  };

  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = [
        pkgs.vscode-extensions.enkia.tokyo-night
        pkgs.vscode-extensions.catppuccin.catppuccin-vsc
      ];
    };
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/vscode-settings.json";
}
