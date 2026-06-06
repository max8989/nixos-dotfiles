###############################################################################
# PLACEHOLDER hardware configuration.
#
# This file MUST be regenerated on the real machine with:
#
#     sudo nixos-generate-config --show-hardware-config \
#       > hosts/thinkpad-x1-carbon-g7/hardware-configuration.nix
#
# It will contain the actual filesystems, LUKS devices, kernel modules and
# CPU/GPU details for the ThinkPad X1 Carbon 7th Gen. The values below are only
# enough to let `nix flake check` evaluate; they are NOT bootable as-is.
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

  # TODO: replace with the generated fileSystems entries.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # Intel graphics (X1 Carbon 7th gen).
  hardware.graphics.enable = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
