# Command-line essentials shared by the desktop and headless server.
# Keep graphical applications and the larger development SDKs in home.nix.
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Shell aliases and terminal file management.
    eza
    bat
    fastfetch
    yazi

    # General utilities and script dependencies.
    htop
    wget
    curl
    fd
    ripgrep
    jq
    dnsutils
    psmisc
    zip
    stow

    # GitHub and Docker administration.
    lazygit
    gh
    docker-compose
    lazydocker

    # Core development runtimes and package managers.
    bun
    uv
    nodejs
    yarn
  ];

  # LazyVim and UltiSnips live in the separate Neovim config repository.
  # Load provider settings through the wrapper so that init.lua stays writable.
  programs.neovim = {
    enable = true;
    withPython3 = true;
    sideloadInitLua = true;
    extraPackages = with pkgs; [
      gcc
      gnumake
      unzip
      tree-sitter
      lua-language-server
      stylua
      shfmt
      fzf
      tmux
      wl-clipboard
    ];
  };
}
