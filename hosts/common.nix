###############################################################################
# Shared system configuration imported by every host's configuration.nix —
# desktops AND headless servers.
#
# Everything here is host-agnostic and role-agnostic. Desktop-only config
# (Hyprland, greetd, PipeWire, fonts, laptop peripherals) lives in
# ./desktop.nix, imported only by graphical hosts. Per-machine bits
# (filesystems, kernel modules, microcode, GPU driver packages) live in each
# host's own hardware-configuration.nix / configuration.nix — NOT here.
###############################################################################
{
  pkgs,
  username,
  fullName,
  hostname,
  ...
}:
{
  ##########################################################################
  ## Boot / kernel
  ##########################################################################
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Compressed swap is the first tier on every host. Pages in zram remain in
  # RAM, but compression gives memory reclaim more room before earlyoom must
  # kill an application. The disk-backed overflow tier is host-specific.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 100;
  };

  # Prefer cheap zram swapping over evicting executable page cache. Disable
  # swap readahead because zram is random-access, and start reclaim earlier to
  # avoid the bursty cache-refault stalls seen under memory pressure.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
  };

  ##########################################################################
  ## Nix / flakes
  ##########################################################################
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  ##########################################################################
  ## Networking / locale / time
  ##########################################################################
  networking.hostName = hostname;
  networking.networkmanager.enable = true;
  # NetworkManager OpenVPN plugin — import/use .ovpn configs from the applet.
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
  # Wi-Fi power save adds 20-100ms wake-up latency to every packet even at
  # full signal (iwlwifi sleeps between beacons) — measured 34ms RTT to the
  # local gateway with it on. Bursty stalls in ssh/git/nix and dropped SSH
  # sessions; not worth the battery. No-op on wired hosts (homeserver).
  networking.networkmanager.wifi.powersave = false;

  # IPv6 kill switch for IPv4-only VPNs.
  #
  # The `maxime-server` OpenVPN profile is IPv4-only: `tun0` gets no IPv6 and
  # the server pushes no `route-ipv6`, so the RA-provided IPv6 default route on
  # wlan stays up. Result: IPv4 goes through the tunnel while every
  # IPv6-capable site still sees the real ISP address — a full geolocation
  # leak, and the reason whatismyipaddress reports the wrong country.
  #
  # On `vpn-up`, if the tunnel itself carries no global IPv6, install an
  # `unreachable` IPv6 default at metric 1. It outranks the RA route (metric
  # 600), so global IPv6 connects fail immediately with ENETUNREACH and Happy
  # Eyeballs falls straight back to IPv4-over-the-tunnel. Link-local and
  # on-link IPv6 keep working via more-specific routes, and NetworkManager's
  # own IPv6 state is left alone — NM does RA in userspace with
  # `accept_ra = 0`, so toggling `disable_ipv6` instead would drop the address
  # and need a device reapply to get it back (and `conf.all` would take `::1`
  # on loopback down with it). Removed again on `vpn-down`; if NM or the
  # machine dies with the VPN up the route simply stays — fail closed.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "vpn-ipv6-killswitch" ''
        # $1 = interface (VPN_IP_IFACE for vpn-* actions), $2 = action
        ip=${pkgs.iproute2}/bin/ip

        case "$2" in
          vpn-up)
            if [ -z "$("$ip" -6 addr show dev "$1" scope global 2>/dev/null)" ]; then
              "$ip" -6 route replace unreachable default metric 1
            fi
            ;;
          vpn-down)
            "$ip" -6 route del unreachable default metric 1 2>/dev/null || true
            ;;
        esac
      '';
    }
  ];

  # Firewall (mirrors the old Arch ufw setup: deny incoming, allow SSH/HTTP/HTTPS).
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
      53317 # Localsend
    ];
    # mDNS — Chrome does its own multicast discovery for Google Cast (it does
    # not go through avahi), and drops the responses without this. Also what
    # `services.avahi.openFirewall` would open if avahi were ever enabled.
    allowedUDPPorts = [
      5353
      53317
    ];
  };

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  ##########################################################################
  ## Misc system services
  ##########################################################################
  security.polkit.enable = true;
  services.dbus.enable = true;
  # Keep enough headroom for the machine to remain responsive while earlyoom
  # terminates a process, and make kills visible to the logged-in user.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 15;
    freeMemKillThreshold = 8;
    enableNotifications = true;
  };

  ##########################################################################
  ## Virtualisation — Docker (dev block). User added to the docker group below.
  ##########################################################################
  virtualisation.docker.enable = true;

  ##########################################################################
  ## User
  ##########################################################################
  users.users.${username} = {
    isNormalUser = true;
    description = fullName;
    # nixos-anywhere installs reboot straight into the system with no
    # interactive `passwd` step, so seed a throwaway first-login password.
    # Only applies when the account is first created (users are mutable);
    # change it immediately after first login with `passwd`.
    initialPassword = "changeme";
    # `uinput` is added by desktop.nix — the group only exists where
    # hardware.uinput is enabled.
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
      "docker"
    ];
    shell = pkgs.zsh;
  };

  ##########################################################################
  ## SSH
  ##
  ## Remote access for debugging a machine whose graphical session is broken
  ## (a Hyprland config error drops you to a bind-less emergency session, but
  ## sshd still works). Password auth is on because this is a laptop on a
  ## trusted LAN with no keys provisioned yet — once you have added a key to
  ## ~/.ssh/authorized_keys, set PasswordAuthentication = false.
  ##########################################################################
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # zsh must be enabled at the NixOS level too, not just in Home Manager:
  # this is what registers it in /etc/shells and makes it valid as a login
  # shell for users.users.<name>.shell above.
  programs.zsh.enable = true;

  # System-wide packages kept minimal; user software lives in Home Manager.
  environment.systemPackages = with pkgs; [
    # Link-layer diagnostics. Needed at the system level because a NIC that
    # auto-negotiates down (a USB dongle settling on 10BASE-T over a bad cable,
    # say) looks exactly like a slow ISP or a slow VPN from userspace —
    # `ethtool <iface>` is what tells the two apart, and `ethtool -s` forces a
    # renegotiation.
    ethtool
    git
    vim
  ];

  # First NixOS generation this config targets. Do not change after install.
  system.stateVersion = "26.05"; # the release first installed; never bump after install
}
