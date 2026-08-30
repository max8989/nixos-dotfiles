# Declarative disk layout (disko) — homeserver (H81M-HD2 desktop).
#
# Used twice:
#   1. At install time: `nixos-anywhere` (or the two-step disko +
#      nixos-install route — see README "Install") partitions, formats, and
#      mounts the device below from this description.
#   2. On the running system: the disko NixOS module derives fileSystems.*
#      from it, so hardware-configuration.nix must NOT define filesystems
#      (it is generated with `nixos-generate-config --no-filesystems`).
#
# ⚠️ Installing with this file ERASES the device below — including the old
# Arch install, all Docker volumes, and the media library. Back everything up
# first, and confirm the device with `ls -l /dev/disk/by-id/` on the target
# before running the install.
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    # by-id, not /dev/sdX: the board also exposes an empty card-reader slot
    # (sda, 0 B) and letter assignment is not stable across boots.
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_500GB_S6PXNM0W412042T";
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
