"""Exercise the production picker on private headless Sway, with fake IPC data.

Run inside nix develop .#quickshell: python3 tests/window-switcher.py BUNDLE OUTPUT
"""
from pathlib import Path
import json
import os
import signal
import subprocess
import sys
import time

bundle, output = (Path(p).resolve() for p in sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
(output / "dispatches").unlink(missing_ok=True)
runtime = output / "runtime"
runtime.mkdir(mode=0o700, exist_ok=True)
for name in ("state", "cache", "config"):
    (output / name).mkdir(exist_ok=True)
env = os.environ.copy()
for key in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "DBUS_SESSION_BUS_ADDRESS"):
    env.pop(key, None)
env.update(XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(output / "cache"),
           XDG_CONFIG_HOME=str(output / "config"), QS_STATE_DIR=str(output / "state"),
           QS_SETTINGS=str(output / "settings.json"), QS_PREVIEW="0",
           WLR_BACKENDS="headless", WLR_RENDERER="pixman", WLR_LIBINPUT_NO_DEVICES="1",
           QT_QUICK_BACKEND="software", QT_QUICK_CONTROLS_STYLE="Basic")
clients = [{"address": address, "mapped": True, "hidden": False, "focusHistoryID": rank,
            "title": title, "class": {"0xa": "kitty", "0xb": "firefox", "0xc": "uninstalled-program"}[address], "workspace": workspace}
           for address, rank, title, workspace in (
               ("0xa", 0, "Current window", {"id": 1, "name": "1"}),
               ("0xb", 1, "Special workspace window", {"address": "special:magic", "name": "special:magic"}),
               ("0xc", 2, "Oldest window", {"name": "chat"}))]
(output / "clients.json").write_text(json.dumps(clients))
(output / "delay").write_text("0")
fake = output / "hyprctl"
fake.write_text(f'''#!{sys.executable}
from pathlib import Path
import sys, time
root = Path({str(output)!r})
if sys.argv[1:] == ["-j", "clients"]:
    time.sleep(float((root / "delay").read_text()))
    print((root / "clients.json").read_text())
else:
    assert len(sys.argv) == 3 and sys.argv[1] == "dispatch"
    assert sys.argv[2].startswith('hl.dsp.focus({{window = "address:0x')
    with (root / "dispatches").open("a") as log:
        log.write(" ".join(sys.argv[1:]) + "\\n")
''')
fake.chmod(0o700)
settings = json.loads((bundle / "generated.json").read_text())
settings["bin"]["hyprctl"] = str(fake)
settings["paths"]["themeState"] = str(output / "missing-theme")
(output / "settings.json").write_text(json.dumps(settings))
link = output / "bundle"
if link.is_symlink():
    link.unlink()
link.symlink_to(bundle, target_is_directory=True)
fixture = output / "shell.qml"
fixture.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "bundle/panels"
import "bundle" as Desktop
ShellRoot {
    WindowSwitcher {}
    IpcHandler {
        target: "qa"
        function locked(value: bool): void { Desktop.Runtime.locked = value; }
    }
}
''')
(output / "sway.conf").write_text("output HEADLESS-1 resolution 1280x800\nseat seat0 fallback true\n")
processes = []
bus_pid = None

def run(args, check=True):
    return subprocess.run(args, env=env, capture_output=True, text=True, check=check, timeout=10)

def wait(predicate):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("Timed out; inspect shell.log and compositor.log")

def ipc(method):
    return run(["quickshell", "ipc", "--path", str(fixture), "call", "switcher", method]).stdout

def state():
    return json.loads(ipc("state"))

def dispatches():
    path = output / "dispatches"
    return path.read_text().splitlines() if path.exists() else []

try:
    bus = run(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"]).stdout.splitlines()
    env["DBUS_SESSION_BUS_ADDRESS"] = bus[0]
    bus_pid = int(bus[1])
    log = (output / "compositor.log").open("w")
    processes.append(subprocess.Popen(["sway", "--config", str(output / "sway.conf")], env=env, stdout=log, stderr=log))
    wait(lambda: (runtime / "wayland-1").exists())
    env["WAYLAND_DISPLAY"] = "wayland-1"
    log = (output / "shell.log").open("w")
    processes.append(subprocess.Popen(["quickshell", "--path", str(fixture), "--no-color"], env=env, stdout=log, stderr=log))
    wait(lambda: "target switcher" in run(["quickshell", "ipc", "--path", str(fixture), "show"], check=False).stdout)
    ipc("next")
    wait(lambda: state()["open"])
    assert state()["selected"] == 1
    assert state()["windows"][1]["workspace"] == "special:magic"
    ipc("previous")
    assert state()["selected"] == 0
    ipc("previous")
    assert state()["selected"] == 2
    run(["wtype", "-s", "150", "-k", "Right", "-s", "100"])
    wait(lambda: state()["selected"] == 0)
    run(["grim", str(output / "picker.png")])
    run(["wtype", "-s", "150", "-k", "Alt_L", "-s", "100"])
    wait(lambda: not state()["open"])
    assert dispatches() == ['dispatch hl.dsp.focus({window = "address:0xa"})']
    ipc("next")
    wait(lambda: state()["open"])
    run(["wtype", "-s", "150", "-k", "Escape", "-s", "100"])
    wait(lambda: not state()["open"])
    assert len(dispatches()) == 1, "Escape must not switch"
    many_clients = clients + [dict(clients[0], address=hex(i + 16), focusHistoryID=i,
                                  title=f"Additional window {i}") for i in range(3, 12)]
    (output / "clients.json").write_text(json.dumps(many_clients))
    ipc("next")
    wait(lambda: state()["open"])
    run(["wtype", "-s", "150", "-k", "Down", "-s", "100"])
    wait(lambda: state()["selected"] == 6)
    run(["wtype", "-s", "150", "-k", "Up", "-s", "100"])
    wait(lambda: state()["selected"] == 1)
    for _ in range(10):
        ipc("next")
    assert state()["selected"] == 11
    run(["grim", str(output / "picker-many.png")])
    ipc("cancel")
    (output / "clients.json").write_text(json.dumps(clients))
    (output / "delay").write_text("0.3")
    ipc("next")
    assert state()["loading"]
    ipc("accept")
    wait(lambda: len(dispatches()) == 2)
    assert dispatches()[-1] == 'dispatch hl.dsp.focus({window = "address:0xb"})', "quick tap must accept after loading"
    assert not state()["open"]
    ipc("next")
    ipc("cancel")
    time.sleep(0.5)
    assert not state()["open"] and not state()["loading"], "late response must not reopen a cancelled picker"
    ipc("next")
    run(["quickshell", "ipc", "--path", str(fixture), "call", "qa", "locked", "true"])
    time.sleep(0.5)
    assert not state()["open"] and not state()["loading"]
    assert len(dispatches()) == 2
    errors = [line for line in (output / "shell.log").read_text().splitlines()
              if any(word in line for word in ("TypeError", "ReferenceError", "Binding loop", "Unable to assign"))]
    assert not errors, errors
    print("Picker passed: MRU, special workspaces, reverse/wrap, grid navigation/overflow, Alt release, Escape, quick tap, cancellation and lock races")
finally:
    for process in reversed(processes):
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
    if bus_pid:
        os.kill(bus_pid, signal.SIGTERM)
