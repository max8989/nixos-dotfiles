# Project N.O.M.A.D. (offline knowledge server) on the portable Samsung SSD.
#
# The whole NOMAD tree — compose.yml + secrets, MySQL, Redis, content — lives
# on the drive's ext4 "NOMAD" partition, so it moves between hosts with the
# drive. Upstream's compose file hard-codes /opt/project-nomad (and its
# self-updater rewrites that file in place), so the drive mounts exactly
# there on every host instead of patching paths.
#
# compose.yml on the drive is upstream's management_compose.yaml with the
# "replaceme" secrets filled in, URL=${NOMAD_URL:-…}, and the published ports
# bound to ${NOMAD_BIND:-127.0.0.1} / 127.0.0.1 (Docker-published ports
# bypass the NixOS firewall, and NOMAD has no authentication).
#
# Plug the drive in → the mount and the stack come up. Before unplugging:
#   sudo systemctl stop 'opt-project\x2dnomad.mount'
# which stops the stack (`compose down`) first, then unmounts.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mountPoint = "/opt/project-nomad";
  uuid = "113b871f-14ee-4f24-8d95-113fa1f87d5e";
  # systemd-escaped unit name of /dev/disk/by-uuid/<uuid>.
  deviceUnit = "dev-disk-by\\x2duuid-${lib.replaceStrings [ "-" ] [ "\\x2d" ] uuid}.device";
  mountUnit = "opt-project\\x2dnomad.mount";
  docker = "${config.virtualisation.docker.package}/bin/docker";
  compose = "${docker} compose -p project-nomad -f ${mountPoint}/compose.yml";
in
{
  fileSystems.${mountPoint} = {
    device = "/dev/disk/by-uuid/${uuid}";
    fsType = "ext4";
    options = [
      "nodev"
      "nosuid"
      "nofail"
      "x-systemd.device-timeout=15s"
    ];
  };

  # Containers keep restart=unless-stopped, so dockerd restores them at boot
  # even when the drive is absent — and would then mkdir the bind-mount
  # sources on the root disk (MySQL initialising a fresh empty database
  # there). An immutable, empty mountpoint makes those binds fail instead.
  # Only touched while nothing is mounted on it.
  systemd.services.project-nomad-mountpoint-guard = {
    description = "Make the unmounted NOMAD mountpoint immutable";
    wantedBy = [ "docker.service" ];
    before = [
      "docker.service"
      mountUnit
    ];
    unitConfig.DefaultDependencies = false;
    after = [ "local-fs-pre.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p ${mountPoint}
      if ! mountpoint -q ${mountPoint}; then
        chattr +i ${mountPoint}
      fi
    '';
    path = [
      pkgs.e2fsprogs # chattr (btrfs root supports FS_IMMUTABLE_FL)
      pkgs.util-linux # mountpoint
    ];
  };

  systemd.services.project-nomad = {
    description = "Project N.O.M.A.D. stack on the portable drive";
    # Start when the drive appears; stop when it disappears.
    wantedBy = [ deviceUnit ];
    bindsTo = [ deviceUnit ];
    requires = [ "docker.service" ];
    after = [
      deviceUnit
      "docker.service"
    ];
    unitConfig = {
      RequiresMountsFor = mountPoint;
      ConditionPathExists = "${mountPoint}/compose.yml";
    };
    environment = {
      NOMAD_URL = lib.mkDefault "http://localhost:8080";
      NOMAD_BIND = lib.mkDefault "127.0.0.1";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${compose} up -d --remove-orphans";
      ExecStop = "${compose} down";
      TimeoutStartSec = "15min"; # first start pulls the images
    };
  };
}
