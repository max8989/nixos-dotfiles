# Minimal Home Manager profile for headless hosts (selected by the
# `desktop = false` flag in flake.nix). Shares the exact same shell experience
# as the desktops (zsh + starship + fzf/zoxide from ./shell.nix) but pulls in
# no graphical software — the server's actual services run in Docker (see
# hosts/homeserver/configuration.nix), not here.
{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./shell.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05"; # match system.stateVersion

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # --- CLI tools the shell.nix aliases depend on ---
    eza # ls/ll/la/lt aliases
    bat # `cat` alias
    fastfetch # `neofetch` alias
    neovim # `n` alias

    # --- general CLI ---
    htop
    btop
    wget
    curl
    fd
    ripgrep
    jq
    zip
    unzip
    dnsutils # dig / nslookup
    lm_sensors
    tmux
    ncdu # disk usage — a 500 GB media disk fills up

    # --- managing the Docker media stack ---
    docker-compose
    lazydocker
    lazygit
  ];
}
