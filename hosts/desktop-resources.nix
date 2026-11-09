# Laptop policy: isolate interactive work before enabling pressure-based kills.
{ lib, ... }:
{
  # Override the shared earlyoom policy only on the desktop importing this file.
  services.earlyoom.enable = lib.mkForce false;
  zramSwap.memoryPercent = lib.mkForce 100;
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 150;
  nix.settings = {
    max-jobs = 1;
    cores = 4;
  };

  systemd.oomd = {
    enable = true;
    enableRootSlice = false;
    enableSystemSlice = false;
    enableUserSlices = false;
    settings.OOM = {
      DefaultMemoryPressureLimit = "50%";
      DefaultMemoryPressureDurationSec = "20s";
    };
  };
  # Monitoring an ancestor owned by the same user is necessary for oomd to
  # honor ManagedOOMPreference=avoid on that user's individual app scopes.
  # Swap-triggered selection ignores these preferences, so leave it disabled.
  systemd.user.slices.app.sliceConfig = {
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMSwap = "auto";
  };
  # D-Bus's ExecStartPost leaves an accounted socket cgroup even after it exits.
  # oomd can repeatedly select that empty normal-priority group, preventing
  # fallback to an important app. Keep session sockets with their services.
  systemd.user.sockets = lib.genAttrs [ "dbus" "pipewire" "pipewire-pulse" ] (_: {
    overrideStrategy = "asDropin";
    socketConfig.Slice = "session.slice";
  });
}
