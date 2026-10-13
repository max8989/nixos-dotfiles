# Home Manager profile for headless hosts (desktop = false in flake.nix).
# Shares the desktop's CLI essentials and shell, with extra administration
# tools. Server services are configured in hosts/homeserver, not here.
{
  pkgs,
  username,
  ...
}:
{
  imports = [
    ./cli.nix
    ./shell.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05"; # match system.stateVersion

  # Let Home Manager manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Terminal sessions, resource usage, and file operations.
    btop
    nvtopPackages.nvidia
    unzip
    tmux
    ncdu
    file
    tree
    rsync

    # Process, hardware, disk, and network diagnostics.
    lsof
    strace
    lm_sensors
    smartmontools
    pciutils
    usbutils
    inetutils
    iperf3
    openssl

    # Edit and validate this configuration and run maintenance scripts.
    nixfmt
    python3
  ];
}
