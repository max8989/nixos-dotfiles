# Runtime desktop themes. Keep Tokyo Night's captured palette unchanged.
let
  tokyo = import ./omarchy-palette.nix;
  latteColors = builtins.fromTOML (builtins.readFile ./files/omarchy/catppuccin-latte-colors.toml);
  latte = {
    name = "Catppuccin-Latte";
    mode = "light";
    background = latteColors.background;
    base = latteColors.dark_background;
    darkest = latteColors.darker_background;
    surface = latteColors.lighter_background;
    raised = latteColors.selection;
    border = latteColors.muted;
    text = latteColors.foreground;
    muted = latteColors.light_foreground;
    dim = latteColors.dark_foreground;
    brightText = latteColors.bright_foreground;
    accent = latteColors.accent;
    green = latteColors.green;
    teal = latteColors.cyan;
    blue = latteColors.blue;
    lavender = latteColors.magenta;
    yellow = latteColors.yellow;
    warning = latteColors.orange;
    urgent = latteColors.red;
    selection = latteColors.selection;
    ansi = [
      latteColors.background
      latteColors.red
      latteColors.green
      latteColors.yellow
      latteColors.blue
      latteColors.magenta
      latteColors.cyan
      latteColors.foreground
      latteColors.muted
      latteColors.bright_red
      latteColors.bright_green
      latteColors.bright_yellow
      latteColors.bright_blue
      latteColors.bright_magenta
      latteColors.bright_cyan
      latteColors.bright_foreground
    ];
    iconTheme = "Yaru-blue";
    vscodeTheme = "Catppuccin Latte";
    fcitxTheme = "Catppuccin-Latte";
    wallpaper = ./files/backgrounds/catppuccin-latte.webp;
  };
in
{
  tokyo-night = tokyo // {
    mode = "dark";
    iconTheme = "Yaru-magenta";
    vscodeTheme = "Tokyo Night";
    fcitxTheme = "Jade";
    wallpaper = ./files/backgrounds/nixos-cool-wallpaper.png;
  };
  catppuccin-latte = latte;
}
