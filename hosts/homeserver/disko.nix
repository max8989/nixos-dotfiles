# Installed disk layout — homeserver (H81M-HD2, BIOS boot).
#
# NixOS is installed on the Corsair SSD with an MBR partition table, an
# ext4 root partition, and an 8.8 GiB swap partition. The disko module
# derives fileSystems and swapDevices from this existing layout; a normal
# nixos-rebuild does not partition or format disks. The Samsung 500 GB Arch
# SSD is separate; media-storage.nix mounts the Samsung 1 TB media partition.
# This disko layout only describes the Corsair system disk.
#
# Sector boundaries were read from /sys/block/sda on the installed server
# (512-byte sectors). MBR requires disko's legacy table type.
# Running disko in destroy/format mode ERASES this disk.
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/ata-Corsair_Neutron_XT_SSD_155281320FF103720100";
    content = {
      type = "table";
      format = "msdos";
      partitions = [
        {
          name = "root";
          start = "2048s";
          end = "919248143s";
          fs-type = "ext4";
          bootable = true;
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        }
        {
          name = "swap";
          start = "919248144s";
          end = "937703087s";
          fs-type = "linux-swap";
          content = {
            type = "swap";
            priority = 0; # zram (priority 100) fills first
          };
        }
      ];
    };
  };
}
