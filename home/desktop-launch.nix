{ pkgs, lib }:
let
  launch = pkgs.writeShellApplication {
    name = "desktop-launch";
    runtimeInputs = [
      pkgs.app2unit
      pkgs.systemd
      pkgs.coreutils
      pkgs.xdg-utils
    ];
    text = builtins.readFile ./files/scripts/desktop-launch.sh;
  };
  open = pkgs.writeShellApplication {
    name = "desktop-open";
    text = ''
      exec ${lib.getExe launch} --important --open -- "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "desktop-launch";
  paths = [ launch open ];
  meta.mainProgram = "desktop-launch";
}
