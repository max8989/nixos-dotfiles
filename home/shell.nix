{ lib, ... }:
{
  programs.bash.enable = true;

  # Starship prompt. The complex Catppuccin-Mocha starship.toml (nerd-font
  # glyphs, palettes) is imported as-is via importTOML — pure (the file lives in
  # the flake) and lossless, which hand-transcribing the unicode glyphs is not.
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = lib.importTOML ./starship.toml;
  };
}
