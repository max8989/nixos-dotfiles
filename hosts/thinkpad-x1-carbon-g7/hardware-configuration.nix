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

  # TODO: replace with the generated fileSystems entries. The install steps in
  # README format the root as btrfs with an `@` subvolume (matching the Gen 12),
  # so the regen will emit `fsType = "btrfs"; options = [ "subvol=@" ];` against
  # a by-uuid device. These by-label placeholders only let `nix flake check`
  # evaluate; they are NOT bootable as-is.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # NOTE: hardware.graphics.enable lives in ./configuration.nix (not here), so it
  # survives regenerating this file. Don't re-add it here.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
