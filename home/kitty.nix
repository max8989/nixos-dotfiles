{ config, ... }:
{
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono Nerd Font";
      size = 9;
    };

    settings = {
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      background_opacity = "0.94";
      window_padding_width = 14;
    };

    keybindings = {
      "ctrl+plus" = "change_font_size all +1.0";
      "ctrl+minus" = "change_font_size all -1.0";
      "ctrl+0" = "change_font_size all 0";
      "ctrl+equal" = "change_font_size all +1.0";
      "ctrl+shift+plus" = "change_font_size all +1.0";
      "ctrl+shift+minus" = "change_font_size all -1.0";
    };
  };

  # Kitty follows the desktop's light/dark preference and updates open windows.
  xdg.configFile."kitty/dark-theme.auto.conf".source = "${config.localTheme.themeDirs.tokyo-night}/kitty.conf";
  xdg.configFile."kitty/light-theme.auto.conf".source = "${config.localTheme.themeDirs.catppuccin-latte}/kitty.conf";
  xdg.configFile."kitty/no-preference-theme.auto.conf".source = "${config.localTheme.themeDirs.tokyo-night}/kitty.conf";
}
