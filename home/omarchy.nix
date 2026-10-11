{ config, pkgs, ... }:
let
  # Osaka Jade uses this exact extension in Omarchy. It is not in nixpkgs.
  oceanGreen = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      publisher = "jovejonovski";
      name = "ocean-green";
      version = "1.1.2";
      hash = "sha256-sUNjnzqXya23Uieg8RLcEfnxiX0ImZ6CIjFtSJ66vM4=";
    };
    meta.license = pkgs.lib.licenses.mit;
  };
in
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
        pkgs.vscode-extensions.jdinhlife.gruvbox
        pkgs.vscode-extensions.arcticicestudio.nord-visual-studio-code
        oceanGreen
      ];
    };
  };

  xdg.configFile."Code/User/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/vscode-settings.json";
}
