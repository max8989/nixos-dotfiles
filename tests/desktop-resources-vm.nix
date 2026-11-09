{ pkgs, home }:
let
  inherit (pkgs) lib;
  launcher = import ../home/desktop-launch.nix { inherit pkgs lib; };
  probe = pkgs.writeText "desktop-launch-probe.py" ''
    import json
    import os
    import pathlib
    import signal
    import sys

    pathlib.Path(sys.argv[1]).write_text(json.dumps({
        "pid": os.getpid(),
        "cgroup": pathlib.Path("/proc/self/cgroup").read_text().strip().split(":", 2)[2],
        "cwd": os.getcwd(),
        "args": sys.argv[2:],
        "marker": os.environ.get("RESOURCE_TEST_MARKER"),
    }))
    signal.pause()
  '';
  pressure = pkgs.writeShellScript "desktop-pressure-probe" ''
    echo "$$" > "$1.pid"
    while [[ ! -e "$1.go" ]]; do sleep 0.1; done
    # Like nixpkgs' systemd-oomd test, force anonymous-memory reclaim with a
    # small memory.high. This runs ONLY inside this VM, with an app.slice cap.
    exec ${pkgs.coreutils}/bin/tail /dev/zero
  '';
  swayConfig = pkgs.writeText "resource-test-sway.conf" ''
    output HEADLESS-1 resolution 1024x768
    output HEADLESS-1 bg #203040 solid_color
    seat seat0 fallback true
  '';
  sessionServices = [
    "quickshell"
    "hypridle"
    "hyprpaper"
    "hyprsunset"
    "kanata"
  ];
in
assert lib.all (
  name: home.systemd.user.services.${name}.Service.Slice == "session.slice"
) sessionServices;
pkgs.testers.runNixOSTest {
  name = "desktop-resources";
  nodes.machine = { ... }: {
    imports = [ ../hosts/desktop-resources.nix ];
    virtualisation.memorySize = 1536;
    virtualisation.cores = 2;
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      priority = 100;
    };
    users.users.alice = {
      isNormalUser = true;
      uid = 1000;
      linger = true;
    };
    services.dbus.enable = true;
    hardware.graphics.enable = true;
    fonts.packages = [ pkgs.dejavu_fonts ];
    environment.systemPackages = [
      launcher
      pkgs.sway
      pkgs.kitty
      pkgs.grim
      pkgs.python3
      pkgs.procps
      pkgs.jq
      pkgs.xdg-utils
    ];
    systemd.tmpfiles.rules = [
      "d /home/alice/.config 0755 alice users -"
      "d /home/alice/.config/systemd 0755 alice users -"
      "d /home/alice/.config/systemd/user 0755 alice users -"
      "d /home/alice/.config/systemd/user/kitty-.scope.d 0755 alice users -"
      "L+ /home/alice/.config/systemd/user/kitty-.scope.d/50-memory-priority.conf - - - - ${
        home.xdg.configFile."systemd/user/kitty-.scope.d/50-memory-priority.conf".source
      }"
    ];
    environment.etc."xdg/mimeapps.list".text = ''
      [Default Applications]
      x-scheme-handler/resource-test=resource-test.desktop
    '';
    environment.etc."resource-test.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Resource test
      Exec=${pkgs.python3}/bin/python3 ${probe} /run/user/1000/entry.json %U
      Path=/tmp/desktop entry cwd
      Terminal=false
      MimeType=x-scheme-handler/resource-test;
    '';
    systemd.user.services.resource-test-session = {
      bindsTo = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "exec";
        Slice = "session.slice";
        ExecStart = "${pkgs.sway}/bin/sway --config ${swayConfig}";
      };
      environment = {
        WLR_BACKENDS = "headless";
        WLR_RENDERER = "pixman";
        WLR_LIBINPUT_NO_DEVICES = "1";
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
      };
    };
    # These limits are test-only: the workload must never exhaust the VM's
    # entire RAM. Keep the production oomd PSI threshold and duration intact.
    systemd.user.slices.app.sliceConfig.MemoryMax = "512M";
  };
  testScript = ''
    import json
    import shlex

    machine.start()
    machine.wait_for_unit("systemd-oomd.service")
    machine.wait_for_unit("user@1000.service")

    def user(command):
        return "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus WAYLAND_DISPLAY=wayland-1 XDG_CURRENT_DESKTOP=Hyprland LIBGL_ALWAYS_SOFTWARE=1 RESOURCE_TEST_MARKER='preserved environment' bash -c " + shlex.quote(command)

    def start(command, label):
        machine.succeed(user(command + " > /run/user/1000/" + label + ".log 2>&1 &"))

    def record(name):
        path = "/run/user/1000/" + name + ".json"
        machine.wait_until_succeeds("test -s " + path, timeout=30)
        return json.loads(machine.succeed("cat " + path))

    def prop(unit, name):
        return machine.succeed(user("systemctl --user show " + shlex.quote(unit) + " -p " + name + " --value")).strip()

    def check_scope(data, preference):
        assert "/app.slice/" in data["cgroup"], data
        unit = data["cgroup"].rsplit("/", 1)[1]
        assert unit.endswith(".scope"), unit
        assert prop(unit, "ManagedOOMPreference") == preference
        return unit

    def stop(unit):
        machine.succeed(user("systemctl --user stop " + shlex.quote(unit)))

    try:
        machine.succeed("mkdir -p '/tmp/desktop entry cwd' '/tmp/command cwd'; chmod 777 '/tmp/desktop entry cwd' '/tmp/command cwd'")
        machine.succeed(user("mkdir -p ~/.local/share/applications; cp /etc/resource-test.desktop ~/.local/share/applications/"))
        machine.succeed(user("systemctl --user start resource-test-session.service"))
        machine.wait_until_succeeds("test -S /run/user/1000/wayland-1", timeout=30)
        assert prop("resource-test-session.service", "Slice") == "session.slice"
        assert prop("dbus.socket", "Slice") == "session.slice"
        assert prop("dbus-broker.service", "Slice") == "session.slice"
        assert prop("app.slice", "ManagedOOMMemoryPressure") == "kill"
        assert prop("app.slice", "ManagedOOMSwap") == "auto"
        machine.fail("systemctl is-active earlyoom.service")

        with subtest("command scopes preserve arguments, working directory and environment"):
            args = ["two words", "$(touch /tmp/should-not-exist)", "$RESOURCE_TEST_MARKER", "", "--literal-option"]
            command = "cd '/tmp/command cwd'; desktop-launch --important -- ${pkgs.python3}/bin/python3 ${probe} /run/user/1000/command.json " + shlex.join(args)
            start(command, "command")
            data = record("command")
            unit = check_scope(data, "avoid")
            assert data["cwd"] == "/tmp/command cwd", data
            assert data["args"] == args, data
            assert data["marker"] == "preserved environment", data
            machine.fail("test -e /tmp/should-not-exist")
            stop(unit)

        with subtest("desktop entries and URL opening get separate application scopes"):
            start("desktop-launch --normal -- resource-test.desktop 'resource-test://two words'", "entry")
            data = record("entry")
            unit = check_scope(data, "none")
            assert data["cwd"] == "/tmp/desktop entry cwd", data
            assert data["args"] == ["resource-test://two words"], data
            stop(unit)
            machine.succeed("rm /run/user/1000/entry.json")
            start("desktop-open 'resource-test://protected document'", "open")
            data = record("entry")
            unit = check_scope(data, "avoid")
            assert data["args"] == ["resource-test://protected document"]
            stop(unit)

        with subtest("real Kitty child scope is protected separately from its window"):
            start("desktop-launch -- kitty --config NONE -o linux_display_server=wayland -o allow_remote_control=no ${pkgs.python3}/bin/python3 ${probe} /run/user/1000/kitty.json", "kitty")
            data = record("kitty")
            child_unit = check_scope(data, "avoid")
            assert child_unit.startswith("kitty-"), child_unit
            parent_pid = int(machine.succeed("ps -o ppid= -p " + str(data["pid"])).strip())
            parent_cgroup = machine.succeed("cat /proc/" + str(parent_pid) + "/cgroup").strip().split(":", 2)[2]
            assert parent_cgroup != data["cgroup"]
            parent_unit = check_scope({"cgroup": parent_cgroup}, "avoid")
            machine.succeed(user("grim /tmp/resource-terminal.png"))
            machine.copy_from_machine("/tmp/resource-terminal.png", "resource-terminal.png")
            # Kitty may keep its window after a child is terminated; close the
            # two independent scopes explicitly before the pressure workload.
            stop(child_unit)
            stop(parent_unit)

        with subtest("missing executable reports failure"):
            machine.fail(user("desktop-launch -- command-that-does-not-exist-resource-test"))

        with subtest("oomd sacrifices normal work first, then permits emergency fallback"):
            scopes = {}
            for name, preference in [("important", "avoid"), ("normal", "none")]:
                prefix = "/run/user/1000/" + name
                start("desktop-launch --" + name + " -- ${pressure} " + prefix, name)
                machine.wait_until_succeeds("test -s " + prefix + ".pid", timeout=30)
                pid = machine.succeed("cat " + prefix + ".pid").strip()
                cgroup = machine.succeed("cat /proc/" + pid + "/cgroup").strip().split(":", 2)[2]
                unit = check_scope({"cgroup": cgroup}, preference)
                scopes[name] = unit
                machine.succeed(user("systemctl --user set-property --runtime " + shlex.quote(unit) + " MemoryHigh=8M"))
            # Both scopes are ready before pressure starts, so preference rather
            # than launch order decides the first victim.
            machine.succeed("touch /run/user/1000/important.go /run/user/1000/normal.go")
            def killed(unit):
                return "journalctl --no-pager -o cat | grep -F 'systemd-oomd killed ' | grep -F " + shlex.quote(unit)
            machine.wait_until_succeeds(killed(scopes["normal"]), timeout=150)
            machine.wait_until_succeeds(killed(scopes["important"]), timeout=150)
            oom_log = machine.succeed("journalctl -u systemd-oomd --no-pager -o cat")
            victims = [line for line in oom_log.splitlines() if " for killing due to memory pressure " in line]
            assert scopes["normal"] in victims[0], victims
            assert scopes["important"] in victims[1], victims
            machine.succeed(user("systemctl --user is-active resource-test-session.service"))
            machine.succeed("systemctl is-active user@1000.service")
            machine.fail("journalctl -k --no-pager -g 'oom-kill:|Out of memory:|Memory cgroup out of memory' | grep -v '^-- No entries --$'")
    finally:
        print(machine.succeed("cat /run/user/1000/*.log /run/user/1000/*.json 2>/dev/null || true"))
        machine.succeed("journalctl -u systemd-oomd --no-pager > /tmp/oomd.log")
        machine.copy_from_machine("/tmp/oomd.log", "oomd.log")
        machine.succeed("journalctl --no-pager > /tmp/journal.log")
        machine.copy_from_machine("/tmp/journal.log", "journal.log")
  '';
}
