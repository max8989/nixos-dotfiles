{ lib, ... }:
let
  palette = import ./omarchy-palette.nix;
in
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
      background = palette.background;
      foreground = palette.text;
      cursor = palette.brightText;
      cursor_text_color = palette.background;
      selection_background = palette.selection;
      selection_foreground = palette.brightText;
      url_color = palette.teal;
      active_border_color = palette.accent;
      inactive_border_color = palette.border;
      active_tab_background = palette.accent;
      active_tab_foreground = palette.background;
      inactive_tab_background = palette.background;
      inactive_tab_foreground = palette.muted;
    }
    // lib.listToAttrs (
      lib.imap0 (i: color: lib.nameValuePair "color${toString i}" color) palette.ansi
    );

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
