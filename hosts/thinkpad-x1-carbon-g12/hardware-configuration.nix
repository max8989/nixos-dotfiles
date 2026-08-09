###############################################################################
# Hardware configuration — ThinkPad X1 Carbon Gen 12 (21KC).
#
# GENERATED — do not hand-edit. Produced by `nixos-generate-config` on the
# machine itself and committed verbatim (only reformatted to repo style).
#
# Filesystems are NOT defined here — they come from ./disko.nix (the disko
# module derives fileSystems.* from the declarative layout). This file only
# carries detected hardware: kernel modules, microcode, platform.
#
# To refresh it on the running machine:
#
#     sudo nixos-generate-config --no-filesystems --show-hardware-config \
#       > hosts/thinkpad-x1-carbon-g12/hardware-configuration.nix
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
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Meteor Lake NPU (Intel AI Boost) — detected on this machine.
  hardware.cpu.intel.npu.enable = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
