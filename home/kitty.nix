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

  # Every appearance preference follows the selected desktop palette.
  xdg.configFile = builtins.listToAttrs (
    map
      (mode: {
        name = "kitty/${mode}-theme.auto.conf";
        value.source = config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/kitty.conf";
      })
      [
        "dark"
        "light"
        "no-preference"
      ]
  );
}
