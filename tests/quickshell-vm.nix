{ pkgs, bundle }:
let
  settings = pkgs.runCommand "quickshell-test-settings.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq '.user = "alice" | .paths.home = "/home/alice" | .paths.todo = "/home/alice/TODO.md"' ${bundle}/generated.json > "$out"
  '';
  shell = pkgs.writeShellScript "test-quickshell" ''
    echo "$$" > "$XDG_RUNTIME_DIR/quickshell.pid"
    exec ${pkgs.quickshell}/bin/quickshell --path ${bundle}/shell.qml --no-color > "$XDG_RUNTIME_DIR/shell.log" 2>&1
  '';
  swayConfig = pkgs.writeText "quickshell-test-sway.conf" ''
    output HEADLESS-1 resolution 1280x800
    output HEADLESS-1 bg #203040 solid_color
    seat seat0 fallback true
    exec ${shell}
  '';
  compositor = pkgs.writeShellScript "test-compositor" ''
    # pam_systemd supplies /run/user/1000; keep this test's sockets in its own runtime.
    export XDG_RUNTIME_DIR=/run/quickshell-test
    echo "$DBUS_SESSION_BUS_ADDRESS" > "$XDG_RUNTIME_DIR/bus"
    exec ${pkgs.sway}/bin/sway --config ${swayConfig}
  '';
  polkitRequest = pkgs.writeShellScript "test-polkit-request" ''
    /run/wrappers/bin/pkexec --disable-internal-agent ${pkgs.coreutils}/bin/id -u > "$XDG_RUNTIME_DIR/polkit-result"
    echo "$?" > "$XDG_RUNTIME_DIR/polkit-status"
  '';
in
pkgs.testers.runNixOSTest {
  name = "quickshell-authentication";
  nodes.machine = { ... }: {
    virtualisation.memorySize = 2048;
    fonts.packages = [
      pkgs.noto-fonts-cjk-sans
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.figtree
    ];
    users.users.alice = {
      isNormalUser = true;
      uid = 1000;
      initialPassword = "quickshell-test";
    };
    security.pam.services.quickshell.fprintAuth = false;
    security.pam.services.quickshell-fingerprint.text = ''
      auth requisite ${pkgs.pam}/lib/security/pam_deny.so
      account requisite ${pkgs.pam}/lib/security/pam_deny.so
    '';
    security.polkit.enable = true;
    security.polkit.enablePkexecWrapper = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id === "org.freedesktop.policykit.exec" && subject.user === "alice")
          return polkit.Result.AUTH_SELF;
      });
    '';
    environment.systemPackages = [
      pkgs.quickshell
      pkgs.wtype
      pkgs.grim
      pkgs.libnotify
      pkgs.sway
      pkgs.procps
      (pkgs.python3.withPackages (p: [ p.pillow ]))
    ];
    systemd.services.quickshell-test = {
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-user-sessions.service" ];
      serviceConfig = {
        User = "alice";
        PAMName = "login";
        RuntimeDirectory = "quickshell-test";
        StateDirectory = "quickshell-test";
        ExecStart = "${pkgs.dbus}/bin/dbus-run-session -- ${compositor}";
        KillMode = "control-group";
      };
      environment = {
        XDG_RUNTIME_DIR = "/run/quickshell-test";
        WLR_BACKENDS = "headless";
        WLR_RENDERER = "pixman";
        WLR_LIBINPUT_NO_DEVICES = "1";
        QT_QUICK_BACKEND = "software";
        QT_QUICK_CONTROLS_STYLE = "Basic";
        QS_STATE_DIR = "/var/lib/quickshell-test";
        QS_SETTINGS = toString settings;
      };
    };
  };
  testScript = ''
    from datetime import timedelta
    machine.start()
    machine.wait_for_unit("quickshell-test.service")
    def user(command):
        return "runuser -u alice -- env XDG_RUNTIME_DIR=/run/quickshell-test WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=\"$(cat /run/quickshell-test/bus)\" " + command
    def ipc(command):
        return user("quickshell ipc --path ${bundle} " + command)
    try:
        machine.wait_until_succeeds(ipc("show") + " | grep 'target session'", timeout=60)
        machine.succeed("python3 -c 'import json,pathlib; paths=json.load(open(\"${settings}\"))[\"paths\"]; assert all(pathlib.Path(paths[key]).is_file() for key in [\"phrases\",\"vim\",\"lazyvim\"])'")
        machine.succeed(user("notify-send -a QA -t 200 'Notification test' 'Plain text <tag>'"))
        machine.wait_until_succeeds(ipc("call notifications count") + " | grep -qx 1")
        machine.wait_until_succeeds(ipc("call notifications popupCount") + " | grep -qx 0")
        notification_id = machine.succeed(user("notify-send -p -t 0 'Persistent notification'")).strip()
        machine.succeed(user("notify-send -r " + notification_id + " -t 0 'Replacement notification'"))
        machine.succeed(ipc("call notifications count") + " | grep -qx 2")
        machine.succeed(ipc("call notifications clear"))
        machine.succeed(ipc("call notifications toggleDnd"))
        machine.succeed(user("notify-send 'Quiet notification'"))
        machine.succeed(ipc("call notifications count") + " | grep -qx 1")
        machine.succeed(ipc("call notifications popupCount") + " | grep -qx 0")
        machine.succeed(ipc("call notifications toggleDnd"))
        machine.succeed(ipc("call notifications clear"))
        machine.succeed(ipc("call menus toggle apps"))
        machine.succeed(user("wtype -s 200 -k Escape"))
        machine.succeed(ipc("call session lock"))
        machine.wait_until_succeeds(ipc("call session isSecure") + " | grep -qx true", timeout=30)
        machine.succeed(user("grim /tmp/locked.png"))
        machine.copy_from_machine("/tmp/locked.png", "locked.png")
        # Quickshell 0.3.1 reports an unknown IPC method with exit status zero.
        assert "unlock" not in machine.succeed(ipc("show"))
        machine.succeed(user("wtype -s 200 -d 30 wrong-password -k Return"))
        machine.sleep(duration=timedelta(seconds=3))
        machine.succeed(ipc("call session isSecure") + " | grep -qx true")
        machine.succeed(user("wtype -s 200 -d 30 quickshell-test -k Return"))
        machine.wait_until_succeeds(ipc("call session isSecure") + " | grep -qx false", timeout=30)
        machine.succeed(user("grim /tmp/unlocked.png"))
        machine.copy_from_machine("/tmp/unlocked.png", "unlocked.png")
        machine.wait_until_succeeds(ipc("call auth isRegistered") + " | grep -qx true", timeout=30)
        def challenge():
            machine.succeed("rm -f /run/quickshell-test/polkit-status")
            machine.succeed(user("swaymsg -s /run/quickshell-test/sway-ipc.1000.*.sock exec ${polkitRequest}"))
            machine.wait_until_succeeds(ipc("call auth isActive") + " | grep -qx true", timeout=30)
        challenge()
        machine.succeed(user("wtype -s 200 -k Escape"))
        machine.wait_for_file("/run/quickshell-test/polkit-status")
        machine.fail("grep -qx 0 /run/quickshell-test/polkit-status")
        challenge()
        machine.succeed(user("wtype -s 200 -d 30 quickshell-test -k Return"))
        machine.wait_until_succeeds("grep -qx 0 /run/quickshell-test/polkit-status", timeout=30)
        machine.succeed("grep -qx 0 /run/quickshell-test/polkit-result")
        machine.succeed(ipc("call session lock"))
        machine.wait_until_succeeds(ipc("call session isSecure") + " | grep -qx true", timeout=30)
        machine.succeed("kill -9 $(cat /run/quickshell-test/quickshell.pid)")
        # A client crash must not expose the desktop's solid #203040 wallpaper.
        # Compositors may reject capture or return their abandoned-lock surface.
        machine.sleep(duration=timedelta(seconds=1))
        status, _ = machine.execute(user("grim /tmp/after-crash.png"))
        if status == 0:
            machine.copy_from_machine("/tmp/after-crash.png", "after-crash.png")
            machine.succeed("python3 -c 'from PIL import Image; im=Image.open(\"/tmp/after-crash.png\").convert(\"RGB\"); assert (32,48,64) not in {color for count,color in im.getcolors(im.width*im.height)}'")
        machine.copy_from_machine("/run/quickshell-test/shell.log", "shell.log")
        machine.succeed("! grep -E 'TypeError|ReferenceError|Failed to load configuration|Binding loop' /run/quickshell-test/shell.log")
        machine.succeed(user("swaymsg -s /run/quickshell-test/sway-ipc.1000.*.sock exec ${shell}"))
        machine.wait_until_succeeds(ipc("call session isSecure") + " | grep -qx true", timeout=30)
        machine.succeed(user("wtype -s 200 -d 30 quickshell-test -k Return"))
        machine.wait_until_succeeds(ipc("call session isSecure") + " | grep -qx false", timeout=30)
        machine.copy_from_machine("/run/quickshell-test/shell.log", "recovered-shell.log")
        machine.succeed("! grep -E 'TypeError|ReferenceError|Failed to load configuration|Binding loop' /run/quickshell-test/shell.log")
    finally:
        print(machine.execute("journalctl -u quickshell-test.service --no-pager -n 40")[1])
        print(machine.execute("cat /run/quickshell-test/shell.log")[1])
  '';
}
