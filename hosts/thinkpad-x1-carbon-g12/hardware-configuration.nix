###############################################################################
# PLACEHOLDER hardware configuration — ThinkPad X1 Carbon Gen 12 (21KC).
#
# This file MUST be regenerated on the real machine, once booted into the NixOS
# installer (or NixOS itself), with:
#
#     sudo nixos-generate-config --show-hardware-config \
#       > hosts/thinkpad-x1-carbon-g12/hardware-configuration.nix
#
# The values below are only enough to let `nix flake check` evaluate; they are
# NOT bootable as-is. They are seeded to match the known facts about this
# machine (Meteor Lake CPU, btrfs root, NVMe) so the diff after regen is small:
#   - CPU: Intel Core Ultra 5 125U (Meteor Lake) -> kvm-intel, intel microcode
#   - Root filesystem: btrfs (regen will emit the real subvolumes + options)
#   - /boot: EFI system partition (vfat)
#
# Do NOT hand-edit this to "fix" a build — regenerate it on the machine.
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

  # TODO: replace with the generated fileSystems entries. The real root is
  # btrfs and almost certainly uses subvolumes (e.g. subvol=@), which
  # nixos-generate-config will fill in along with the correct UUIDs.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@" ];
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  # TODO: if the install uses a swap partition/file, the generator emits it
  # here. (The current Arch install reports ~7.5 GiB of swap.)
  swapDevices = [ ];

  # Intel microcode — Meteor Lake.
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # DHCP default; networking.networkmanager (in common.nix) manages the links.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
