{ pkgs, lib, ... }:
{
  home.packages = [ (import ./desktop-launch.nix { inherit pkgs lib; }) ];

  # These services sustain the session, including the lock screen and keyboard.
  # Keep them outside the application slice monitored by systemd-oomd.
  systemd.user.services =
    lib.genAttrs [ "quickshell" "hypridle" "hyprpaper" "hyprsunset" "kanata" ]
      (_: {
        Service.Slice = "session.slice";
      });

  # Kitty creates a separate sibling scope for each shell in its own slice.
  # The terminal's preference does not propagate to those scopes.
  xdg.configFile."systemd/user/kitty-.scope.d/50-memory-priority.conf".text =
    lib.generators.toINI { }
      { Scope.ManagedOOMPreference = "avoid"; };
}
