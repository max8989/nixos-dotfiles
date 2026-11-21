# Nightly prebuilt updates for the graphical hosts.
#
# At ~03:30 this updates flake.lock in a private clone of this repo, builds
# every desktop host's whole system against it, pushes the result to the Attic
# cache (./attic.nix) and only then commits + pushes flake.lock. A nixpkgs that
# breaks the desktop therefore never reaches it: the laptop's `nixos-update`
# (home/nixos-update.nix) pulls the last lock that built and downloads it.
#
# nix build runs as root so it can cap jobs/cores and add the desktop caches.
# git, ssh and attic run as ${username}: the GitHub key and
# ~/.config/attic/config.toml (from `attic login`) live in that home.
#
# Test by hand: sudo systemctl start prebuild-desktop && journalctl -fu prebuild-desktop
{
  config,
  lib,
  pkgs,
  username,
  desktopHosts,
  ...
}:
let
  remote = "git@github.com:max8989/nixos-dotfiles.git";
  branch = "main";
  cache = "homeserver:main";
  stateDir = "/var/lib/prebuild-desktop";
  work = "${stateDir}/nixos-config";
  caches = import ../desktop-caches.nix;

  script = pkgs.writeShellScript "prebuild-desktop" ''
    set -euo pipefail
    as_user() {
      ${pkgs.util-linux}/bin/runuser -u ${username} -- env HOME=/home/${username} PATH="$PATH" \
        GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=20" "$@"
    }

    [ -d ${work}/.git ] || as_user git clone -q ${remote} ${work}
    cd ${work}
    as_user git fetch -q origin ${branch}
    # -f: a failed run leaves flake.lock modified; a plain checkout would refuse forever.
    as_user git checkout -q -f -B ${branch} origin/${branch}
    as_user git clean -qfdx

    as_user nix flake update

    # Each out-link is a GC root, so GC can't delete what the desktop is about
    # to download. path: because root can't open a git repo another user owns.
    # The homeserver doesn't use the desktop's upstream caches itself; without
    # them Hyprland would be compiled here.
    ${lib.concatMapStrings (host: ''
      echo "Building ${host}"
      nix build --max-jobs 2 --cores 2 \
        --option extra-substituters ${lib.escapeShellArg (toString caches.substituters)} \
        --option extra-trusted-public-keys ${lib.escapeShellArg (toString caches.trusted-public-keys)} \
        --out-link ${stateDir}/result-${host} \
        "path:${work}#nixosConfigurations.${host}.config.system.build.toplevel"
    '') desktopHosts}

    # Pushes resume (paths already cached are skipped), so retry instead of
    # throwing away a long build.
    for try in 1 2 3; do
      as_user attic push ${cache} ${
        lib.concatMapStringsSep " " (host: "${stateDir}/result-${host}") desktopHosts
      } && break
      [ "$try" = 3 ] && { echo "attic push failed 3 times"; exit 1; }
      sleep 300
    done

    if as_user git diff --quiet -- flake.lock; then
      echo "flake.lock unchanged."
    else
      as_user git -c user.name="nightly prebuild" -c user.email="${username}@${config.networking.hostName}" \
        commit -q -m "nightly: update flake.lock (pre-built)" -- flake.lock
      as_user git push -q origin ${branch} || { echo "push rejected, retry tomorrow"; exit 0; }
    fi
  '';
in
{
  systemd.services.prebuild-desktop = {
    description = "Update flake.lock and pre-build the desktop hosts into Attic";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "atticd.service"
    ];
    path = [
      config.nix.package
      pkgs.git
      pkgs.openssh
      pkgs.attic-client
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = script;
      StateDirectory = "prebuild-desktop";
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -o ${username} -g users ${work}";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.prebuild-desktop = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "03:30";
      RandomizedDelaySec = "30m";
      Persistent = true; # missed while the server was off: run at next boot
    };
  };
}
