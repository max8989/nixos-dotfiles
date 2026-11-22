{ pkgs, lib }:
let
  app2unit = pkgs.app2unit.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      # Keep caller argv literal through systemd and app2unit's POSIX IFS
      # splitting. A final separator preserves a trailing empty argument.
      substituteInPlace "$out/bin/app2unit" \
        --replace-fail 'set -- systemd-run --user "$@"' 'set -- systemd-run --user --expand-environment=no "$@"' \
        --replace-fail 'set -- $a2u__command' 'set -- $a2u__command$A2U__USEP' \
        --replace-fail 'set -- $A2U__EXEC_RSEP_USEP' 'set -- $A2U__EXEC_RSEP_USEP$A2U__USEP' \
        --replace-fail 'set -- $a2u__cmd' 'set -- $a2u__cmd$A2U__USEP'
      # Accept `!` in Entry IDs (osu-lazer ships `osu!.desktop`). Unit names
      # stay valid: app2unit systemd-escapes any non [a-zA-Z:_.] substring.
      substituteInPlace "$out/bin/app2unit" \
        --replace-fail \
          '*[!a-zA-Z0-9_.-]* | *[!a-zA-Z0-9_.-] | [!a-zA-Z0-9_.-]* | [!a-zA-Z0-9_.-] |' \
          '*[!a-zA-Z0-9_.!-]* | *[!a-zA-Z0-9_.!-] | [!a-zA-Z0-9_.!-]* | [!a-zA-Z0-9_.!-] |' \
        --replace-fail "! -path \"\$a2u__fe_directory\"'./*[^a-zA-Z0-9_./-]*'" \
          "! -path \"\$a2u__fe_directory\"'./*[^a-zA-Z0-9_./!-]*'"
    '';
  });
  launch = pkgs.writeShellApplication {
    name = "desktop-launch";
    runtimeInputs = [
      app2unit
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
  paths = [
    launch
    open
  ];
  meta.mainProgram = "desktop-launch";
  passthru = { inherit app2unit; };
}
