# Runtime desktop themes mapped from the preserved Omarchy source palettes.
let
  tokyo = import ./omarchy-palette.nix;
  fromOmarchy =
    {
      name,
      displayName,
      colors,
      iconTheme,
      vscodeTheme,
      wallpaper,
    }:
    {
      inherit
        name
        displayName
        iconTheme
        vscodeTheme
        wallpaper
        ;
      mode = colors.mode;
      background = colors.background;
      base = colors.dark_background;
      darkest = colors.darker_background;
      surface = colors.lighter_background;
      raised = colors.selection;
      border = colors.muted;
      text = colors.foreground;
      muted = colors.light_foreground;
      dim = colors.dark_foreground;
      brightText = colors.bright_foreground;
      accent = colors.accent;
      green = colors.green;
      teal = colors.cyan;
      blue = colors.blue;
      lavender = colors.magenta;
      yellow = colors.yellow;
      warning = colors.orange;
      urgent = colors.red;
      selection = colors.selection;
      ansi = [
        colors.background
        colors.red
        colors.green
        colors.yellow
        colors.blue
        colors.magenta
        colors.cyan
        colors.foreground
        colors.muted
        colors.bright_red
        colors.bright_green
        colors.bright_yellow
        colors.bright_blue
        colors.bright_magenta
        colors.bright_cyan
        colors.bright_foreground
      ];
      fcitxTheme = name;
    };
  darkTheme =
    id: name: displayName: wallpaper:
    let
      source = ./files/omarchy + "/${id}";
    in
    fromOmarchy {
      inherit name displayName wallpaper;
      colors = builtins.fromTOML (builtins.readFile (source + "/colors.toml"));
      iconTheme = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile (source + "/icons.theme"));
      vscodeTheme = (builtins.fromJSON (builtins.readFile (source + "/vscode.json"))).name;
    };
in
{
  tokyo-night = tokyo // {
    displayName = "Tokyo Night";
    mode = "dark";
    iconTheme = "Yaru-magenta";
    vscodeTheme = "Tokyo Night";
    fcitxTheme = tokyo.name;
    wallpaper = ./files/backgrounds/nixos-cool-wallpaper.png;
  };
  catppuccin-latte = fromOmarchy {
    name = "Catppuccin-Latte";
    displayName = "Catppuccin Latte";
    colors = builtins.fromTOML (builtins.readFile ./files/omarchy/catppuccin-latte-colors.toml);
    iconTheme = "Yaru-blue";
    vscodeTheme = "Catppuccin Latte";
    wallpaper = ./files/backgrounds/catppuccin-latte.webp;
  };
  osaka-jade = darkTheme "osaka-jade" "Osaka-Jade" "Osaka Jade" ./files/backgrounds/osaka-jade.webp;
  catppuccin =
    darkTheme "catppuccin" "Catppuccin-Mocha" "Catppuccin Mocha"
      ./files/backgrounds/catppuccin.webp;
  gruvbox = darkTheme "gruvbox" "Gruvbox" "Gruvbox" ./files/backgrounds/gruvbox.jpg;
  nord = darkTheme "nord" "Nord" "Nord" ./files/backgrounds/nord.jpg;
}
