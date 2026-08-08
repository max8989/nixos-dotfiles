###############################################################################
# Hardware configuration — ThinkPad X1 Carbon 7th Gen.
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
#       > hosts/thinkpad-x1-carbon-g7/hardware-configuration.nix
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
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # NOTE: hardware.graphics.enable lives in ./configuration.nix (not here), so it
  # survives regenerating this file. Don't re-add it here.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
