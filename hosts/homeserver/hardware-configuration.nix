###############################################################################
# Hardware configuration — homeserver (Gigabyte H81M-HD2, i5-4460 Haswell,
# RTX 3070).
#
# ⚠️ PLACEHOLDER — hand-written from known hardware so the flake evaluates
# before the machine runs NixOS. Regenerate it during/after install and commit
# the real output:
#
#     sudo nixos-generate-config --no-filesystems --show-hardware-config \
#       > hosts/homeserver/hardware-configuration.nix
#
# Filesystems are NOT defined here — they come from ./disko.nix (the disko
# module derives fileSystems.* from the declarative layout). This file only
# carries detected hardware: kernel modules, microcode, platform.
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

  # Haswell-era desktop: SATA (ahci), USB3 (xhci) + USB2 (ehci) controllers.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ehci_pci"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # WiFi (wlan0) + anything else needing binary blobs.
  hardware.enableRedistributableFirmware = lib.mkDefault true;
}
