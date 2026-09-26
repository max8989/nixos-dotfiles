###############################################################################
# VPN hotspot — share the maxime-server OpenVPN tunnel with a guest machine.
#
# Two ways in, both NAT'd onto the same tunnel:
#
#   Wi-Fi AP    10.56.0.0/24 ──┐
#                              ├── masquerade ──> tun0
#   Thunderbolt 10.55.0.0/24 ──┘
#
# Guests get an address, a default route and DNS over DHCP; every packet they
# send is masqueraded onto `tun0` and leaves through the VPN. Nothing routes
# them onto the uplink: `networking.nat` scopes both the masquerade and the
# FORWARD accept to `-o tun0`, so if the tunnel is down guest traffic is
# dropped rather than silently falling back to the ISP — the same fail-closed
# stance as the IPv6 kill switch in common.nix.
#
# The Wi-Fi AP takes the radio outright. The chipset does allow concurrent
# station + AP, but only with `#channels <= 1` (the AP is pinned to whatever
# channel the station sits on), so sharing the radio means the uplink dictates
# the AP's channel. Running the laptop's uplink over Ethernet and giving the
# radio entirely to the AP avoids that. It also means the VPN must re-establish
# over the wired link — see README.
#
# Imported by ../desktop.nix; the headless host never sees it.
###############################################################################
{
  lib,
  pkgs,
  username,
  ...
}:
let
  # Thunderbolt guest. Name pinned by the udev rule below — the kernel calls the
  # device `thunderbolt0`, but nothing guarantees that.
  tbIface = "tbnet0";
  tbNet = "10.55.0";

  # Wi-Fi AP guest. The profile deliberately does not name an interface so the
  # same module works on either ThinkPad; NetworkManager picks the wireless
  # device. That is also why the DHCP and firewall rules below are keyed off
  # addresses rather than interface names.
  apNet = "10.56.0";
  apSsid = "${username}-vpn";

  # The VPN interface NetworkManager's OpenVPN plugin creates for
  # `maxime-server`. A second concurrent tunnel would land on tun1 and this
  # would need updating.
  vpnIface = "tun0";

  # Handed to guests over DHCP. Reached *through* the tunnel (a guest's only
  # route out is its subnet -> tun0), so DNS cannot leak to the local router the
  # way it would if we forwarded /etc/resolv.conf, which also lists the LAN
  # gateway. Same resolvers the VPN profile pushes to this host.
  dns = [
    "94.140.14.14"
    "94.140.15.15"
  ];

  guestSubnets = [
    "${tbNet}.0/24"
    "${apNet}.0/24"
  ];

  pskFile = "/etc/nm-hotspot.env";
in
{
  ##########################################################################
  ## Thunderbolt link
  ##########################################################################
  # IP-over-Thunderbolt. Not autoloaded: the driver only binds once an XDomain
  # (host-to-host) connection shows up, which is too late to modprobe by hand.
  boot.kernelModules = [ "thunderbolt-net" ];

  # boltd authorizes the peer under the firmware's Thunderbolt security level
  # (this host reports `security = user`), without which a link never comes up.
  services.hardware.bolt.enable = true;

  # Give the interface a stable name. udev's default policy has no path rule for
  # the Thunderbolt bus, so the name falls back to whatever the kernel picked.
  services.udev.extraRules = ''
    SUBSYSTEM=="net", ACTION=="add", ENV{ID_NET_DRIVER}=="thunderbolt-net", NAME="${tbIface}"
  '';

  ##########################################################################
  ## Guest-facing NetworkManager profiles
  ##########################################################################
  # The AP pre-shared key is generated once into an unmanaged file outside the
  # flake, so it never lands in git. `ensureProfiles` runs the keyfile through
  # envsubst with this file as its environment.
  networking.networkmanager.ensureProfiles.environmentFiles = [ pskFile ];

  system.activationScripts.vpnHotspotSecret = ''
    if [ ! -e ${pskFile} ]; then
      ( umask 077
        echo "HOTSPOT_PSK=$(${pkgs.openssl}/bin/openssl rand -base64 12)" > ${pskFile} )
    fi
  '';

  networking.networkmanager.ensureProfiles.profiles = {
    # NetworkManager ships 90-nm-thunderbolt.rules, which makes auto-generated
    # profiles for Thunderbolt devices link-local only. An explicit profile wins.
    thunderbolt-hotspot = {
      connection = {
        id = "thunderbolt-hotspot";
        type = "ethernet";
        interface-name = tbIface;
        autoconnect = "true";
      };
      ipv4 = {
        method = "manual";
        address1 = "${tbNet}.1/24";
        never-default = "true";
        ignore-auto-dns = "true";
        may-fail = "true";
      };
      # No IPv6 anywhere in here. The tunnel is IPv4-only (see the kill switch
      # in common.nix) and the wired uplink carries a real global IPv6 — handing
      # a guest a routable v6 address would leak straight around the VPN.
      ipv6.method = "disabled";
    };

    # `autoconnect = false`: activating this takes the radio away from the
    # station connection, so it must be an explicit `nmcli con up`, never
    # something that races the uplink at boot.
    wifi-hotspot = {
      connection = {
        id = "wifi-hotspot";
        type = "wifi";
        autoconnect = "false";
      };
      wifi = {
        mode = "ap";
        ssid = apSsid;
        # 2.4 GHz. 5 GHz AP on iwlwifi runs into regulatory no-IR on most
        # channels; switch to `band = "a"` with an explicit `channel` if the
        # extra throughput is worth the fight.
        band = "bg";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        proto = "rsn";
        pairwise = "ccmp";
        group = "ccmp";
        psk = "$HOTSPOT_PSK";
      };
      ipv4 = {
        method = "manual";
        address1 = "${apNet}.1/24";
        never-default = "true";
        ignore-auto-dns = "true";
        may-fail = "true";
      };
      ipv6.method = "disabled";
    };
  };

  ##########################################################################
  ## DHCP for the guests
  ##########################################################################
  # DHCP only — `port = 0` disables the resolver, so this never competes with
  # the host's own DNS and needs no port 53 exposure. No `interface =` on
  # purpose: `bind-dynamic` plus subnet-scoped ranges means dnsmasq answers only
  # where an address of ours exists, which keeps it independent of the wireless
  # device's name and silent on the uplink and the docker bridges.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      port = 0;
      bind-dynamic = true;
      dhcp-authoritative = true;
      dhcp-range = [
        "set:tb,${tbNet}.10,${tbNet}.50,12h"
        "set:ap,${apNet}.10,${apNet}.50,12h"
      ];
      dhcp-option = [
        "tag:tb,option:router,${tbNet}.1"
        "tag:ap,option:router,${apNet}.1"
        "option:dns-server,${lib.concatStringsSep "," dns}"
      ];
    };
  };

  ##########################################################################
  ## NAT onto the tunnel
  ##########################################################################
  # Matching on `internalIPs` rather than `internalInterfaces` keys the rules to
  # the subnets, so they hold however the guest interface is named or whether it
  # exists yet. This adds both the `-s <subnet> -o tun0 -j MASQUERADE` in
  # nat/POSTROUTING and the matching FORWARD accept — the latter matters because
  # Docker sets the FORWARD policy to DROP.
  networking.nat = {
    enable = true;
    externalInterface = vpnIface;
    internalIPs = guestSubnets;
    enableIPv6 = false;
  };

  networking.firewall = {
    # Guest DHCP, and the MSS clamp for forwarded traffic.
    #
    # The DHCP rule is scoped to the client->server port pair rather than to an
    # interface, since the wireless device's name is not known here. dnsmasq
    # still only answers inside the ranges above, so this admits requests it
    # will ignore rather than widening what it serves.
    #
    # Clamping forwarded TCP handshakes to the tunnel's path MTU is a no-op
    # while tun0 sits at 1500, but the moment OpenVPN negotiates anything
    # smaller it is what stops large transfers from hanging while pings and
    # small pages keep working. `extraStopCommands` also runs on reload, so
    # neither rule is appended twice.
    extraCommands = ''
      iptables -A nixos-fw -p udp --sport 68 --dport 67 -j nixos-fw-accept
      iptables -t mangle -A FORWARD -o ${vpnIface} -p tcp --tcp-flags SYN,RST SYN \
        -j TCPMSS --clamp-mss-to-pmtu
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -p udp --sport 68 --dport 67 -j nixos-fw-accept 2>/dev/null || true
      iptables -t mangle -D FORWARD -o ${vpnIface} -p tcp --tcp-flags SYN,RST SYN \
        -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    '';
  };
}
