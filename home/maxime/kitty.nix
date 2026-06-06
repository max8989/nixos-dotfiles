{ ... }:
{
  # Ported from kitty/.config/kitty/kitty.conf. The Catppuccin-Mocha palette is
  # applied declaratively via themeFile (from pkgs.kitty-themes) instead of the
  # old current-theme.conf include.
  programs.kitty = {
    enable = true;

    themeFile = "Catppuccin-Mocha";

    font = {
      name = "CaskaydiaCove Nerd Font Mono";
      size = 12;
    };

    settings = {
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      background_opacity = "0.5";
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
}
