{ pkgs, ... }:
{
  # Desktop-only: the server imports shell.nix but not this module.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "omarchy-tokyo-night";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
    };
    themes.omarchy-tokyo-night = ./files/omarchy/btop.theme;
  };

  programs.vscode = {
    enable = true;
    profiles.default = {
      extensions = [ pkgs.vscode-extensions.enkia.tokyo-night ];
      userSettings."workbench.colorTheme" = "Tokyo Night";
    };
  };
}
