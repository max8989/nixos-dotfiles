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
    neovim

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
}
