"""Test production attention chips and notification activation on private Sway.

Run inside nix develop .#quickshell: python3 tests/workspace-activity.py BUNDLE OUTPUT
"""
from pathlib import Path
import json
import os
import signal
import subprocess
import sys
import tempfile
import time

bundle, output = (Path(p).resolve() for p in sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
(output / "dispatches").unlink(missing_ok=True)
runtime_directory = tempfile.TemporaryDirectory(prefix="qs-wa-", dir="/tmp")
runtime = Path(runtime_directory.name)
for name in ("state", "cache", "config", "data"):
    (output / name).mkdir(exist_ok=True)
env = os.environ.copy()
for key in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "DBUS_SESSION_BUS_ADDRESS"):
    env.pop(key, None)
env.update(XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(output / "cache"),
           XDG_CONFIG_HOME=str(output / "config"), XDG_DATA_HOME=str(output / "data"),
           QS_STATE_DIR=str(output / "state"), QS_SETTINGS=str(output / "settings.json"), QS_PREVIEW="0",
           WLR_BACKENDS="headless", WLR_RENDERER="pixman", WLR_LIBINPUT_NO_DEVICES="1",
           QT_QUICK_BACKEND="software", QT_QUICK_CONTROLS_STYLE="Basic")
(output / "clients.json").write_text(json.dumps([
    {"address": "0xa", "class": "discord", "workspace": {"name": "1"}, "mapped": True, "focusHistoryID": 0, "fullscreen": 2,
     "tags": ["personal-tag", "quickshell-notification"]},
    {"address": "0xb", "class": "kitty", "workspace": {"name": "2"}, "mapped": True, "focusHistoryID": 1, "fullscreen": 1},
]))
(output / "activewindow.json").write_text("{}")
fake = output / "hyprctl"
fake.write_text(f'''#!{sys.executable}
from pathlib import Path
import json
import re
import sys
root = Path({str(output)!r})
if sys.argv[1:] == ["-j", "clients"]:
    print((root / "clients.json").read_text())
    sys.exit(0)
if sys.argv[1:] == ["-j", "activewindow"]:
    print((root / "activewindow.json").read_text())
    sys.exit(0)
if len(sys.argv) == 3 and sys.argv[1] == "--batch":
    clients = json.loads((root / "clients.json").read_text())
    for command in sys.argv[2].split("; "):
        match = re.fullmatch(r'dispatch hl\\.dsp\\.window\\.tag\\(\\{{window = "address:(0x[0-9a-f]+)", tag = "([+-])quickshell-notification"\\}}\\)', command)
        assert match, command
        address, action = match.groups()
        for client in clients:
            if client["address"] == address:
                tags = [tag for tag in client.get("tags", []) if tag != "quickshell-notification"]
                client["tags"] = tags + (["quickshell-notification"] if action == "+" else [])
    temp = root / "clients.next"
    temp.write_text(json.dumps(clients))
    temp.replace(root / "clients.json")
    print("ok")
    sys.exit(0)
assert len(sys.argv) == 3 and sys.argv[1] == "dispatch"
assert sys.argv[2] in ['hl.dsp.focus({{window = "address:0xb"}})', 'hl.dsp.focus({{window = "address:0xc"}})']
with Path({str(output / "dispatches")!r}).open("a") as log:
    log.write(" ".join(sys.argv[1:]) + "\\n")
''')
fake.chmod(0o700)
settings = json.loads((bundle / "generated.json").read_text())
settings["bin"]["hyprctl"] = str(fake)
settings["paths"]["themeState"] = str(output / "missing-theme")
settings["features"].update(lock=False, polkit=False, notifications=False)
(output / "settings.json").write_text(json.dumps(settings))
link = output / "bundle"
if link.is_symlink():
    link.unlink()
link.symlink_to(bundle, target_is_directory=True)
fixture = output / "shell.qml"
fixture.write_text('''pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "bundle" as Desktop
import "bundle/bar" as Bar
import "bundle/services" as Services
import "bundle/widgets" as Widgets
ShellRoot {
    id: root
    property int opened: 0
    property int deleted: 0
    property int expired: 0
    property string kind: "default"
    property var secondState: Services.WindowActivity.workspaceState("2", Services.Notifications.entries)
    property var specialState: Services.WindowActivity.workspaceState("special:magic", Services.Notifications.entries)
    QtObject { id: openAction; property string identifier: "default"; property string text: "Open"; function invoke() { root.opened++; } }
    QtObject { id: deleteAction; property string identifier: "delete"; property string text: "Delete"; function invoke() { root.deleted++; } }
    QtObject {
        id: notice
        signal closed()
        property var value: ({id: 42, summary: "A message needs your attention", body: "Open the matching app window",
            appName: root.kind === "scratchpad" ? "TickTick" : "Discord",
            desktopEntry: root.kind === "scratchpad" ? "com.ticktick.TickTick.desktop" : "discord.desktop",
            image: "", expireTimeout: root.kind === "default" ? 0 : 80, urgency: 1, resident: true,
            actions: root.kind === "default" ? [deleteAction, openAction] : [deleteAction], tracked: false,
            closed: notice.closed, dismiss: function() { notice.closed(); },
            expire: function() { root.expired++; notice.closed(); }})
    }
    TestEvent { id: mouseEvents }
    function find(item, name) {
        if (item.objectName === name || (name === "Delete" && item.text === name)) return item;
        for (var i = 0; i < item.children.length; i++) {
            var result = find(item.children[i], name);
            if (result) return result;
        }
        return null;
    }
    function click(item) { mouseEvents.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 1); }
    function initializeCards() {
        Desktop.Preferences.dnd = false;
        Services.Notifications.receive(notice.value);
    }
    PanelWindow {
        id: panel
        implicitWidth: 580; implicitHeight: 310
        color: Desktop.Config.theme.solid
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Row {
            x: 24; y: 20; spacing: 8
            Bar.WorkspaceChip { id: first; text: "1"; highlighted: true; windowCount: 1 }
            Bar.WorkspaceChip { id: second; text: "2"; attention: root.secondState.urgent; fullscreenWindow: root.secondState.fullscreen; windowCount: root.secondState.count }
            Bar.WorkspaceChip { id: special; text: "S"; attention: root.specialState.urgent; windowCount: root.specialState.count }
        }
        Widgets.NotificationCard {
            id: card
            x: 24; y: 80; width: panel.width - 48
            entry: Services.Notifications.entries[0] || ({app: "", title: "", body: ""})
        }
    }
    IpcHandler {
        target: "qa"
        function inspect(): string {
            var e = Services.Notifications.entries[0];
            return JSON.stringify({opened: root.opened, deleted: root.deleted, expired: root.expired,
                model: {activeAddress: Services.WindowActivity.activeAddress, refreshing: Services.WindowActivity.refreshing,
                        clients: Services.WindowActivity.clients.map(c => ({address: c.address, activated: c.activated, fullscreen: c.fullscreen}))},
                entry: e ? {unread: e.unread, live: !!e.notification, windowAddress: e.windowAddress, desktopEntry: e.desktopEntry} : null,
                popups: Services.Notifications.popups.length,
                firstRadius: first.background.radius, secondRadius: second.background.radius,
                secondBorder: second.background.border.width, firstHeight: first.height,
                dot: root.find(second, "workspaceAttention").visible,
                specialDot: root.find(special, "workspaceAttention").visible,
                firstColor: first.foreground.toString(), secondColor: second.foreground.toString(),
                enabled: root.find(card, "notificationOpen").enabled});
        }
        function notify(value: string): void { root.kind = value; Services.Notifications.receive(notice.value); }
        function refreshCompositor(): void { Services.WindowActivity.refresh(); }
        function startCards(): void { root.initializeCards(); }
        function clickBody(): void { root.click(root.find(card, "notificationOpen")); }
        function clickDelete(): void { root.click(root.find(card, "Delete")); }
        function focusBody(): void { root.find(card, "notificationOpen").forceActiveFocus(Qt.TabFocusReason); }
        function locked(value: bool): void { Desktop.Runtime.locked = value; }
    }
}
''')
(output / "sway.conf").write_text("output HEADLESS-1 resolution 800x480\nseat seat0 fallback true\n")
bus_config = output / "session.conf"
bus_config.write_text(f'''<busconfig>
  <type>session</type>
  <listen>unix:path={runtime / "bus"}</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
''')
processes, bus_pid = [], None

def run(args, check=True):
    try:
        return subprocess.run(args, env=env, capture_output=True, text=True, check=check, timeout=10)
    except subprocess.CalledProcessError as error:
        for captured in (error.stdout, error.stderr):
            if captured:
                print(captured, file=sys.stderr, end="")
        raise

def wait(predicate):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("Timed out; inspect shell.log and compositor.log")

def qa(method, *args):
    return run(["quickshell", "ipc", "--path", str(fixture), "call", "qa", method, *args]).stdout

def state():
    return json.loads(qa("inspect"))

def dispatches():
    path = output / "dispatches"
    return path.read_text().splitlines() if path.exists() else []

def attention():
    return {client["address"] for client in json.loads((output / "clients.json").read_text())
            if "quickshell-notification" in client.get("tags", [])}

def activate(address):
    (output / "activewindow.json").write_text(json.dumps({"address": address}))
    qa("refreshCompositor")
    wait(lambda: state()["model"]["activeAddress"] == address and not state()["model"]["refreshing"])

try:
    bus = run(["dbus-daemon", "--config-file", str(bus_config), "--fork", "--print-address=1", "--print-pid=1"]).stdout.splitlines()
    env["DBUS_SESSION_BUS_ADDRESS"], bus_pid = bus[0], int(bus[1])
    log = (output / "compositor.log").open("w")
    processes.append(subprocess.Popen(["sway", "--config", str(output / "sway.conf")], env=env, stdout=log, stderr=log))
    wait(lambda: (runtime / "wayland-1").exists())
    env["WAYLAND_DISPLAY"] = "wayland-1"
    log = (output / "shell.log").open("w")
    processes.append(subprocess.Popen(["quickshell", "--path", str(fixture), "--no-color"], env=env, stdout=log, stderr=log))
    wait(lambda: "target qa" in run(["quickshell", "ipc", "--path", str(fixture), "show"], check=False).stdout)
    wait(lambda: len(state()["model"]["clients"]) == 2 and not state()["model"]["refreshing"])
    compositor = state()["model"]
    assert compositor["activeAddress"] == "", "MRU rank zero must not activate a window on an empty workspace"
    assert compositor["clients"] == [
        {"address": "0xa", "activated": False, "fullscreen": True},
        {"address": "0xb", "activated": False, "fullscreen": True},
    ], "fullscreen and maximized modes both get the square outline"
    wait(lambda: not attention())
    assert json.loads((output / "clients.json").read_text())[0]["tags"] == ["personal-tag"], "startup clears stale attention while preserving other tags"
    activate("0xa")
    assert state()["model"]["clients"][0]["activated"]
    (output / "clients.json").write_text(json.dumps([
        {"address": "0xa", "class": "kitty", "workspace": {"name": "1"}, "mapped": True, "focusHistoryID": 0},
        {"address": "0xb", "class": "discord", "workspace": {"name": "2"}, "mapped": True, "fullscreen": 1, "focusHistoryID": 1},
        {"address": "0xc", "class": "ticktick", "workspace": {"name": "special:magic"}, "mapped": True, "hidden": True, "focusHistoryID": 2},
    ]))
    qa("refreshCompositor")
    wait(lambda: len(state()["model"]["clients"]) == 3 and not state()["model"]["refreshing"])
    qa("startCards")
    wait(lambda: state()["dot"] and state()["enabled"] and attention() == {"0xb"})
    before = state()
    assert before["firstRadius"] == before["firstHeight"] / 2 and before["secondRadius"] == 4
    assert before["secondBorder"] == 1 and before["firstColor"] != before["secondColor"]
    (output / "attention-state.json").write_text(json.dumps(before, indent=2))
    run(["grim", str(output / "workspace-attention.png")])
    qa("clickBody")
    wait(lambda: state()["opened"] == 1 and not attention())
    assert state()["deleted"] == 0 and not dispatches() and not state()["entry"]["unread"]
    qa("notify", "default")
    qa("focusBody")
    run(["wtype", "-s", "150", "-k", "Return", "-s", "100"])
    wait(lambda: state()["opened"] == 2)
    assert state()["deleted"] == 0 and not dispatches()
    qa("clickDelete")
    assert state()["deleted"] == 1 and state()["opened"] == 2
    qa("notify", "expired")
    wait(lambda: state()["expired"] == 1 and not state()["entry"]["live"] and attention() == {"0xb"})
    assert state()["entry"] == {"unread": True, "live": False, "windowAddress": "0xb", "desktopEntry": "discord.desktop"}
    qa("clickBody")
    wait(lambda: len(dispatches()) == 1 and not attention())
    assert dispatches() == ['dispatch hl.dsp.focus({window = "address:0xb"})']
    assert not state()["dot"] and not state()["entry"]["unread"]
    qa("notify", "expired")
    wait(lambda: state()["expired"] == 2 and attention() == {"0xb"})
    activate("0xb")
    wait(lambda: not state()["entry"]["unread"] and not state()["dot"] and not attention())
    qa("notify", "default")
    assert not state()["entry"]["unread"] and not state()["dot"] and not attention(), "active senders need no attention marker"
    activate("0xa")
    qa("notify", "scratchpad")
    wait(lambda: state()["expired"] == 3 and state()["specialDot"] and attention() == {"0xc"})
    assert not state()["entry"]["live"] and state()["entry"]["windowAddress"] == "0xc"
    qa("clickBody")
    wait(lambda: len(dispatches()) == 2 and not attention())
    assert dispatches()[-1] == 'dispatch hl.dsp.focus({window = "address:0xc"})'
    assert not state()["specialDot"] and state()["deleted"] == 1
    qa("locked", "true")
    activate("0xb")
    qa("notify", "default")
    assert state()["entry"]["unread"], "an activated sender remains unread while the session is locked"
    assert state()["popups"] == 0
    activate("0xa")
    wait(lambda: attention() == {"0xb"})
    activate("0xb")
    wait(lambda: not attention())
    assert state()["entry"]["unread"], "focus changes during lock must not mark notifications read"
    qa("clickBody")
    assert state()["opened"] == 2 and state()["deleted"] == 1 and len(dispatches()) == 2
    qa("locked", "false")
    wait(lambda: not state()["entry"]["unread"])
    errors = [line for line in (output / "shell.log").read_text().splitlines()
              if any(word in line for word in ("TypeError", "ReferenceError", "Binding loop", "Unable to assign"))]
    assert not errors, errors
    print("Workspace activity passed: notification border tags and workspace dots, startup cleanup, popup expiry, active/archived/scratchpad senders, read-on-focus and locked-session unread state")
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
    runtime_directory.cleanup()
