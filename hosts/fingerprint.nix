# Omarchy-style fingerprint authentication, expressed as NixOS configuration.
# Upstream: omacom/omarchy bin/omarchy-setup-security-fingerprint and
# default/systemd/system-sleep/fprintd-resume (see README for source links).
{
  config,
  pkgs,
  ...
}:
let
  lidClosed = pkgs.writeShellScript "fingerprint-lid-closed" ''
    # A closed laptop makes the reader inaccessible. Unknown lid state keeps
    # normal authentication; skipping a scan still requires the password.
    for state in /proc/acpi/button/lid/*/state; do
      if [[ -r "$state" && $(<"$state") == *closed* ]]; then
        exit 0
      fi
    done
    exit 1
  '';
  fingerprintFirst = service: {
    fprintAuth = true;
    rules.auth.fingerprint-lid = {
      order = config.security.pam.services.${service}.rules.auth.fprintd.order - 1;
      control = "[success=1 default=ignore]";
      modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
      args = [
        "quiet"
        "${lidClosed}"
      ];
    };
  };
in
{
  services.fprintd.enable = true;
  security.pam.services = {
    sudo = fingerprintFirst "sudo";
    polkit-1 = fingerprintFirst "polkit-1";
    # The lock runs these conversations in parallel, so a waiting scan never
    # blocks password entry. The fingerprint stack has no password fallback.
    quickshell.fprintAuth = false;
    quickshell-fingerprint = {
      unixAuth = false;
      fprintAuth = true;
    };
  };

  # Resume can leave a stale device claim. Queue recovery: user.slice may
  # still be frozen while the system sleep hook is running.
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl --no-block try-restart fprintd.service || true
  '';
  systemd.services.fprintd.serviceConfig.TimeoutStopSec = "3s";
}
