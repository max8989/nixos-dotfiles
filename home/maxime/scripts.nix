{
  config,
  pkgs,
  lib,
  ...
}:
let
  home = config.home.homeDirectory;

  # Timer scripts run under systemd (no login shell), so give them an explicit
  # PATH with everything they call.
  timerPath = lib.makeBinPath (
    with pkgs;
    [
      bash
      coreutils
      gnugrep
      gawk
      findutils
      jq
      libnotify # notify-send
      upower # battery-level.sh
    ]
  );
in
{
  # upower is also a waybar battery dependency.
  home.packages = [ pkgs.upower ];

  # Custom scripts referenced by keybindings / hyprlock / waybar (screenshot.sh,
  # screen_record.sh, wallpaper-switcher.sh, rofi-fb-official.sh, whatsong.sh,
  # power.sh, …). Carried as in-repo files; their deps come from home.packages.
  #
  # NOTE: waybar/scripts/system-update.sh is Arch-only and self-exits on NixOS
  # (it checks for /etc/arch-release), so it is harmless. Replace later if you
  # want a Nix update indicator.
  xdg.configFile."scripts".source = ./files/scripts;

  ##########################################################################
  ## systemd user timers (ported from systemd/.config/systemd/user/*)
  ##########################################################################
  systemd.user.services.battery-level = {
    Unit.Description = "Battery level notification checker";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${timerPath}";
      ExecStart = "${home}/.config/waybar/scripts/battery-level.sh";
    };
  };
  systemd.user.timers.battery-level = {
    Unit.Description = "Check battery level every minute";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  systemd.user.services.reminders-notify = {
    Unit.Description = "Obsidian reminder notification checker";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${timerPath}";
      ExecStart = "${home}/.config/waybar/scripts/reminders-notify.sh";
    };
  };
  systemd.user.timers.reminders-notify = {
    Unit.Description = "Check for Obsidian reminders every minute";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
