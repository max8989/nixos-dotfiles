{ palette }:
{
  code_syntax_highlight = if palette.mode == "light" then "github" else "github-dark";
  file_panel_border = palette.border;
  sidebar_border = palette.base;
  footer_border = palette.border;
  file_panel_border_active = palette.accent;
  sidebar_border_active = palette.accent;
  footer_border_active = palette.accent;
  modal_border_active = palette.accent;
  full_screen_bg = palette.background;
  file_panel_bg = palette.background;
  sidebar_bg = palette.base;
  footer_bg = palette.base;
  modal_bg = palette.surface;
  full_screen_fg = palette.text;
  file_panel_fg = palette.text;
  sidebar_fg = palette.text;
  footer_fg = palette.text;
  modal_fg = palette.text;
  cursor = palette.accent;
  correct = palette.green;
  error = palette.urgent;
  hint = palette.teal;
  cancel = palette.warning;
  gradient_color = [
    palette.accent
    palette.teal
  ];
  file_panel_top_directory_icon = palette.accent;
  file_panel_top_path = palette.muted;
  file_panel_item_selected_fg = palette.text;
  file_panel_item_selected_bg = palette.raised;
  sidebar_title = palette.accent;
  sidebar_item_selected_fg = palette.text;
  sidebar_item_selected_bg = palette.raised;
  sidebar_divider = palette.border;
  modal_cancel_fg = palette.base;
  modal_cancel_bg = palette.urgent;
  modal_confirm_fg = palette.base;
  modal_confirm_bg = palette.accent;
  help_menu_hotkey = palette.accent;
  help_menu_title = palette.yellow;
}
