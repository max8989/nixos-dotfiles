###############################################################################
# Hardware configuration — ThinkPad X1 Carbon Gen 12 (21KC).
#
# Filesystems are NOT defined here — they come from ./disko.nix (the disko
# module derives fileSystems.* from the declarative layout). This file only
# carries detected hardware: kernel modules, microcode, platform.
#
# `nixos-anywhere --generate-hardware-config nixos-generate-config <this file>`
# regenerates it at install time (with --no-filesystems, so it never conflicts
# with disko). To refresh it on a running machine:
#
#     sudo nixos-generate-config --no-filesystems --show-hardware-config \
#       > hosts/thinkpad-x1-carbon-g12/hardware-configuration.nix
#
# The values below are seeded to match the known facts about this machine
# (Meteor Lake CPU, NVMe) so the diff after regen is small:
#   - CPU: Intel Core Ultra 5 125U (Meteor Lake) -> kvm-intel, intel microcode
###############################################################################
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Intel microcode — Meteor Lake.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # DHCP default; networking.networkmanager (in common.nix) manages the links.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
