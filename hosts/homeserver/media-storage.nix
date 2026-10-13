# Application configs live on the Corsair system disk. This existing ext4
# partition on the Samsung 1 TB SSD holds the Compose stack's /mnt/data.
{ ... }:
{
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/61ae30a8-dd94-44a7-9a25-703468628f30";
    fsType = "ext4";
    options = [
      "nodev"
      "nosuid"
      "nofail"
      "x-systemd.device-timeout=15s"
    ];
  };

  # Containers use their original Compose restart policies. Docker must
  # wait for the media disk before restoring those containers at boot.
  systemd.services.docker.unitConfig.RequiresMountsFor = "/mnt/data";
}
