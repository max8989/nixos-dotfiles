# homeserver — Gigabyte H81M-HD2 desktop (i5-4460 Haswell, 16 GB, RTX 3070).
#
# Headless media server. All host-agnostic system config lives in
# ../common.nix; this host deliberately does NOT import ../desktop.nix — no
# compositor, no login manager, no audio stack. Administer it over SSH.
#
# The media stack (Traefik, Jellyfin, the *arr suite, qBittorrent behind the
# PIA WireGuard container, SABnzbd, Homepage, …) stays in Docker Compose.
# media-storage.nix mounts the Samsung 1 TB library disk. The restored project
# on the Corsair system disk runs with its original Compose restart policies.
{ lib, username, ... }:
{
  imports = [
    ../common.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./portainer.nix
    ./opencode.nix
    ./media-storage.nix
  ];

  # The installed system boots with BIOS GRUB from the Corsair SSD. The
  # shared UEFI defaults belong to the laptop; /boot is part of this root.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-id/ata-Corsair_Neutron_XT_SSD_155281320FF103720100";
    useOSProber = true;
  };

  # Preserve the installation's key-only SSH access and existing account
  # password. The disk-backed swap partition is declared in disko.nix.
  users.users.${username} = {
    initialPassword = lib.mkForce null;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/pvM8FDrjIAsh05zAQ6FbpJrhucYfxiltL7R/PD2Om"
    ];
  };
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce false;
    KbdInteractiveAuthentication = false;
  };

  ##########################################################################
  ## Graphics — RTX 3070, headless.
  ##
  ## The proprietary/open NVIDIA kernel driver is loaded without any display
  ## server (videoDrivers does not pull in X). It exists purely so Docker
  ## containers can use the GPU — Jellyfin NVENC/NVDEC transcoding.
  ##########################################################################
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    # Ampere (GA104) is fully supported by the open kernel modules, which
    # nixpkgs now prefers for Turing+.
    open = true;
    modesetting.enable = true;
    nvidiaSettings = false; # GUI tool — useless headless
    powerManagement.enable = false;
  };
  # Generates CDI specs so containers can request the GPU. With Docker ≥25
  # compose services use:
  #   devices:
  #     - driver: cdi
  #       device_ids: ["nvidia.com/gpu=all"]
  # (or `docker run --device nvidia.com/gpu=all`). The legacy
  # `runtime: nvidia` / NVIDIA_VISIBLE_DEVICES route is not wired up here.
  hardware.nvidia-container-toolkit.enable = true;

  ##########################################################################
  ## Server behaviour
  ##########################################################################
  # Never sleep — this box serves media 24/7 and is administered over SSH.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Reclaim disk from unused images/layers — Watchtower keeps pulling new
  # images and the old ones would otherwise accumulate on a 500 GB disk.
  virtualisation.docker.autoPrune.enable = true;

  # On top of common.nix's 22/80/443: Jellyfin direct access + client
  # auto-discovery (the ports the old compose stack published on the host).
  networking.firewall.allowedTCPPorts = [ 8096 ];
  networking.firewall.allowedUDPPorts = [
    1900 # DLNA / SSDP discovery
    7359 # Jellyfin "who's on this LAN" client discovery
  ];
}
