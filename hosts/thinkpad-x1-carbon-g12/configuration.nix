# ThinkPad X1 Carbon Gen 12 (machine type 21KC) — Intel Core Ultra 5 125U
# (Meteor Lake) with the integrated Intel Graphics (Xe / Arc) iGPU.
#
# All host-agnostic system config lives in ../common.nix. This file wires in the
# shared module + this machine's generated hardware configuration, plus the
# Meteor-Lake-specific GPU video stack.
{ pkgs, ... }:
{
  imports = [
    ../common.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  # Disk-backed overflow for cold anonymous memory. nixpkgs detects btrfs and
  # creates this with `btrfs filesystem mkswapfile`, so the file is NODATACOW
  # and uncompressed despite the root mount's compress=zstd option. Keep it at
  # /: the btrfs setup path does not create a missing parent directory.
  swapDevices = [
    {
      device = "/swapfile";
      size = 8 * 1024; # MiB
      priority = 0; # zram (priority 100) fills first
    }
  ];

  ##########################################################################
  ## Graphics — Meteor Lake iGPU.
  ##
  ## hardware.graphics.enable is set here (rather than in the generated
  ## hardware-configuration.nix) so it survives a `nixos-generate-config`
  ## regen. extraPackages adds hardware-accelerated video decode/encode:
  ##   - intel-media-driver: the iHD VAAPI driver (Gen8+ / Xe / Arc).
  ##   - vpl-gpu-rt: oneVPL GPU runtime, the modern successor to Media SDK
  ##     used by Meteor Lake's media engine.
  ##########################################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };
  # Force the iHD driver for VAAPI consumers (mpv, ffmpeg, browsers).
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  ##########################################################################
  ## Audio — pin the Meteor Lake-P SOF HDA DSP card to the Speaker profile.
  ##
  ## Ported from the Arch wireplumber.conf.d/51-alsa-auto-profile.conf. With
  ## api.acp.auto-profile left on, plugging in HDMI makes WirePlumber switch
  ## this card to the Headphones profile (priority 10300) over the Speaker
  ## profile (10200), which silences the laptop speakers. Pinning the Speaker
  ## profile keeps the speakers alive and still exposes all three HDMI sinks;
  ## auto-port stays on so jack plug/unplug still switches ports.
  ##
  ## Host-specific because the device.name matches this machine's card.
  ##########################################################################
  services.pipewire.wireplumber.extraConfig."51-alsa-auto-profile" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; }
        ];
        actions.update-props = {
          "api.acp.auto-profile" = false;
          "api.acp.auto-port" = true;
          "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)";
        };
      }
    ];
  };
}
