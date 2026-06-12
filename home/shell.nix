{ lib, ... }:
{
  programs.bash.enable = true;

  # Aliases migrated from the old Arch install_packages.sh (~/.bashrc additions).
  programs.bash.shellAliases = {
    grep = "grep --color=auto";
    df = "df -h";
    du = "du -h -c";
    free = "free -h";
    ls = "ls --color=auto";
    ll = "ls -lh";
    la = "ls -A";
    l = "ls -CF";
    lla = "ls -lha";
    c = "clear";
    q = "exit";
    ".." = "cd ..";
    "..." = "cd ../..";
    neofetch = "fastfetch";
    pwdc = "pwd | wl-copy";
    cdo = ''pwd | xargs -I{} echo "cd {} && opencode" | wl-copy'';
    cdc = ''pwd | xargs -I{} echo "cd {} && claude" | wl-copy'';
    cdd = ''pwd | xargs -I{} echo "cd {}" | wl-copy'';
  };

  # Starship prompt. The complex Catppuccin-Mocha starship.toml (nerd-font
  # glyphs, palettes) is imported as-is via importTOML — pure (the file lives in
  # the flake) and lossless, which hand-transcribing the unicode glyphs is not.
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = lib.importTOML ./starship.toml;
  };
}
