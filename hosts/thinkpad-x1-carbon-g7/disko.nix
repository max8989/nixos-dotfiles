# Declarative disk layout (disko) — ThinkPad X1 Carbon 7th Gen.
#
# Used twice:
#   1. At install time: `nixos-anywhere` (or `disko-install`) partitions,
#      formats, and mounts the device below from this description.
#   2. On the running system: the disko NixOS module derives fileSystems.*
#      from it, so hardware-configuration.nix must NOT define filesystems
#      (it is generated with `nixos-generate-config --no-filesystems`).
#
# ⚠️ Installing with this file ERASES the device below. Confirm it with
# `lsblk` on the target before running nixos-anywhere.
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1"; # internal NVMe on the X1 Carbon
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00"; # EFI system partition
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%"; # fills the rest of the disk
          content = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "nixos"
            ];
            subvolumes = {
              "@" = {
                mountpoint = "/";
                mountOptions = [
                  "compress=zstd"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
