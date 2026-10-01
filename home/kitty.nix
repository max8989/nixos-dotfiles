{ ... }:
let
  palette = import ./palette.nix;
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = "CaskaydiaCove Nerd Font Mono";
      size = 12;
    };

    settings = {
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      background_opacity = "0.94";
      background = palette.background;
      foreground = palette.text;
      cursor = palette.accent;
      cursor_text_color = palette.base;
      selection_background = palette.accent;
      selection_foreground = palette.base;
      url_color = palette.teal;
      active_border_color = palette.accent;
      inactive_border_color = palette.border;
      active_tab_background = palette.surface;
      active_tab_foreground = palette.accent;
      inactive_tab_background = palette.background;
      inactive_tab_foreground = palette.muted;
      color0 = palette.surface;
      color1 = palette.urgent;
      color2 = palette.green;
      color3 = palette.yellow;
      color4 = palette.blue;
      color5 = palette.lavender;
      color6 = palette.teal;
      color7 = palette.text;
      color8 = palette.dim;
      color9 = palette.urgent;
      color10 = palette.accent;
      color11 = palette.warning;
      color12 = palette.blue;
      color13 = palette.lavender;
      color14 = palette.teal;
      color15 = palette.text;
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
