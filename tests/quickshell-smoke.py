"""Run visual/UI smoke tests on a private headless Sway and D-Bus session.

Usage (inside nix develop .#quickshell, with sway/grim/wtype/wl-clipboard on PATH):
  python3 tests/quickshell-smoke.py <built-bundle> <output-directory>
Never connects to the user's compositor, clipboard cache, or session bus.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

bundle, output = map(lambda s: Path(s).resolve(), sys.argv[1:])
output.mkdir(parents=True, exist_ok=True)
runtime = output / "runtime"
runtime.mkdir(exist_ok=True, mode=0o700)
for directory in ("state", "cache", "home", "data/applications", "config/quickshell"):
    (output / directory).mkdir(exist_ok=True, parents=True)
(output / "data/applications/quickshell-qa.desktop").write_text("[Desktop Entry]\nType=Application\nName=Quickshell QA Fixture\nExec=false\n")
config_link = output / "config/quickshell/desktop"
if config_link.is_symlink():
    config_link.unlink()
config_link.symlink_to(bundle, target_is_directory=True)
(output / "home" / "TODO.md").write_text("- [ ] Review shell\n- [ ] [[note|中文測試]]\n- [x] Completed\n")
settings = json.loads((bundle / "generated.json").read_text())
settings["paths"].update(home=str(output / "home"), todo=str(output / "home" / "TODO.md"))
(output / "settings.json").write_text(json.dumps(settings))
(output / "sway.conf").write_text("output HEADLESS-1 resolution 1920x1080\noutput HEADLESS-1 bg #20283a solid_color\nseat seat0 fallback true\n")
env = os.environ.copy()
for key in ("WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK", "DBUS_SESSION_BUS_ADDRESS"):
    env.pop(key, None)
env.update(XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(output / "cache"), XDG_DATA_HOME=str(output / "data"), XDG_DATA_DIRS=str(output / "data"), WLR_BACKENDS="headless", WLR_RENDERER="pixman", WLR_LIBINPUT_NO_DEVICES="1", QT_QUICK_BACKEND="software", QT_QUICK_CONTROLS_STYLE="Basic", QS_PREVIEW="1", QS_STATE_DIR=str(output / "state"), QS_SETTINGS=str(output / "settings.json"), QS_NO_RELOAD_POPUP="1")
env["TZ"] = settings.get("timeZone", "UTC")
env["XDG_CONFIG_HOME"] = str(output / "config")
processes = []

def run(args, check=True):
    return subprocess.run(args, env=env, text=True, capture_output=True, check=check, timeout=15)

def wait(predicate, seconds=20):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.1)
    raise AssertionError("Timed out waiting for isolated shell")

def interaction_checks():
    """Exercise production widgets on the private compositor, with test-only IPC.

    The fixture imports the built components unchanged. Authentication and
    notification ownership are disabled; no production diagnostic IPC is added.
    """
    fixture = output / "interactions.qml"
    shutil.copy(Path(__file__).with_name("SettingsFixtures.qml"), output / "SettingsFixtures.qml")
    fixture_bundle = output / "bundle"
    if fixture_bundle.is_symlink():
        fixture_bundle.unlink()
    fixture_bundle.symlink_to(bundle, target_is_directory=True)
    fixture.write_text('''pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "BUNDLE" as Desktop
import "BUNDLE/bar" as Bar
import "BUNDLE/panels" as Panels
import "BUNDLE/services" as Services

ShellRoot {
    id: root
    Bar.Bar { id: bar; modelData: Quickshell.screens[0] }
    property string requestedPower: ""
    Panels.Menus { id: menus; onPowerRequested: action => root.requestedPower = action }
    SettingsFixtures { id: hardware }
    Panels.Overlays {}
    TestEvent { id: mouseEvents }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (var i = 0; i < item.children.length; i++) {
            var result = find(item.children[i], name);
            if (result) return result;
        }
        return null;
    }
    function controls(item, result) {
        if (item.tipTitle && item.visible) {
            var point = item.mapToItem(bar.contentItem, item.width / 2, item.height / 2);
            var tip = null;
            for (var i = 0; i < item.data.length; i++) {
                var candidate = item.data[i];
                if (candidate.target === item && candidate.ready !== undefined)
                    tip = {visible: candidate.visible, width: candidate.width, height: candidate.height,
                           position: candidate.contentItem.mapToGlobal(0, 0)};
            }
            result.push({title: item.tipTitle, x: point.x + Desktop.Config.bar.sideMargin,
                         y: point.y + Desktop.Config.bar.margin, hovered: item.hovered,
                         visualFocus: item.visualFocus, selected: item.selected,
                         borderAlpha: item.background.border.color.a, tip: tip});
        }
        for (var j = 0; j < item.children.length; j++)
            controls(item.children[j], result);
    }
    IpcHandler {
        target: "qa"
        function inspect(): string {
            var buttons = [];
            root.controls(bar.contentItem, buttons);
            var card = null;
            for (var i = 0; i < menus.contentItem.children.length; i++) {
                var child = menus.contentItem.children[i];
                if (child.width > 100 && child.width < menus.width)
                    card = {x: child.x, y: child.y, width: child.width, height: child.height};
            }
            return JSON.stringify({buttons: buttons, card: card, menu: Desktop.Runtime.menu,
                                   message: Desktop.Runtime.message,
                                   query: root.find(menus.contentItem, "menuSearch").text,
                                   rows: menus.filtered.map(r => ({id:r.id || r.title, title:r.title, value:r.value || ""})),
                                   selected: menus.filtered[root.find(menus.contentItem, "menuList").currentIndex]?.id || "",
                                   confirmation: menus.confirmation, requestedPower: root.requestedPower,
                                   cancelFocused: root.find(menus.contentItem, "cancelPower").activeFocus,
                                   cancelVisualFocus: root.find(menus.contentItem, "cancelPower").visualFocus,
                                   dndFocused: root.find(menus.contentItem, "notificationDnd").activeFocus,
                                   calendarMonth: root.find(menus.contentItem, "menuCalendar").shown.getMonth(),
                                   dnd: Desktop.Preferences.dnd,
                                   notificationCount: Services.Notifications.entries.length,
                                   outputVolume: hardware.audio.sink.audio.volume,
                                   outputName: hardware.audio.sink.name,
                                   outputMuted: hardware.audio.sink.audio.muted,
                                   inputVolume: hardware.audio.source.audio.volume,
                                   wifiEnabled: hardware.network.enabled,
                                   wifiRadioEnabled: root.find(menus.contentItem, "wifiRadio").enabled,
                                   wifiBackendWarning: root.find(menus.contentItem, "wifiBackendWarning").visible,
                                   wifiHardwareWarning: root.find(menus.contentItem, "wifiHardwareWarning").visible,
                                   wifiPassword: hardware.network.guest.passwordReceived,
                                   dnsPreset: hardware.network.details.preset,
                                   powerProfile: hardware.battery.profile,
                                   panelTextSize: Desktop.Preferences.panelTextSize,
                                   scaleBusy: Services.Display.scaleBusy,
                                   scaleSeconds: Services.Display.scaleSeconds,
                                   savedScale: Desktop.Preferences.monitorScales["QA display"] || 1,
                                   focused: menus.contentItem.Window.window?.activeFocusItem?.objectName || "",
                                   osdProgress: Desktop.Runtime.osdProgress});
        }
        function openPanel(name: string): void {
            root.find(menus.contentItem, "audioPanel").audio = hardware.audio;
            root.find(menus.contentItem, "wifiPanel").network = hardware.network;
            root.find(menus.contentItem, "batteryPanel").battery = hardware.battery;
            root.find(menus.contentItem, "displayPanel").monitorModel = [{name: "HEADLESS-1", description: "QA display", width: 1920, height: 1200, scale: 1, focused: true}];
            Desktop.Runtime.toggleMenu(name, null);
        }
        function focusControl(name: string): void { root.find(menus.contentItem, name).forceActiveFocus(Qt.TabFocusReason); }
        function selectGuestWifi(): void { menus.connectNetwork(hardware.network.guest); }
        function networkState(available: bool, hardwareEnabled: bool): void {
            hardware.network.available = available;
            hardware.network.hardwareEnabled = hardwareEnabled;
        }
        function openControls(): void { Desktop.Runtime.toggleMenu("controls", null); }
        function addNotification(): void {
            Services.Notifications.entries = [{id: 1234, title: "Keyboard notification", body: "Test history focus and dismissal", app: "QA", time: Date.now(), popup: false}];
        }
        function openClipboard(): void { Desktop.Runtime.toggleMenu("clipboard", null); }
        function point(x: int, y: int): void {
            mouseEvents.mouseMove(bar.contentItem, x - Desktop.Config.bar.sideMargin,
                                  y - Desktop.Config.bar.margin, 1, Qt.NoButton, Qt.NoModifier);
        }
        function click(x: int, y: int): void {
            mouseEvents.mouseClick(bar.contentItem, x - Desktop.Config.bar.sideMargin,
                                   y - Desktop.Config.bar.margin, Qt.LeftButton, Qt.NoModifier, 1);
        }
        function report(): void { Desktop.Runtime.report("Clipboard entry is unavailable. Try another saved entry."); }
    }
}
'''.replace("BUNDLE", "bundle"))
    settings["features"].update(lock=False, polkit=False, notifications=False)
    # The real bar/clipboard paths run; hardware daemons and weather do not.
    settings["bin"]["curl"] = shutil.which("false")
    # A private backlight fixture exercises the real Display service and keyboard
    # adjustments without ever touching the physical screen brightness.
    brightness = output / "brightnessctl"
    brightness.write_text("#!" + sys.executable + "\n" + '''import pathlib, sys
state = pathlib.Path(__file__).with_suffix('.state')
value = int(state.read_text()) if state.exists() else 50
if 'set' in sys.argv:
    change = sys.argv[-1]
    value = max(1, min(100, value + int(change[:-2]) * (1 if change[-1] == '+' else -1) if change[-1] in '+-' else int(change[:-1])))
    state.write_text(str(value))
print(f'qa_backlight,backlight,{value},{value}%,100')
''')
    brightness.chmod(0o700)
    settings["bin"]["brightnessctl"] = str(brightness)
    # Exercise the production QML Process/stdin confirmation protocol without
    # contacting Hyprland. The Python helper's rollback is tested separately.
    settings_helper = output / "settings-helper"
    settings_helper.write_text("#!" + sys.executable + "\n" + '''import json, select, sys
if sys.argv[1] == 'preview-scale':
    print(json.dumps({'state': 'preview', 'seconds': 15}), flush=True)
    readable, _, _ = select.select([sys.stdin], [], [], 15)
    answer = sys.stdin.readline().strip() if readable else ''
    print(json.dumps({'state': 'kept' if answer == 'keep' else 'reverted'}), flush=True)
elif sys.argv[1] == 'battery-info':
    print('{}')
''')
    settings_helper.chmod(0o700)
    settings["bin"]["settings"] = str(settings_helper)
    (output / "settings.json").write_text(json.dumps(settings))
    env["QS_PREVIEW"] = "0"
    # Exercise the real state-path fallback, including an existing Quickshell
    # config alias like the one that made desktop preferences read-only.
    env.pop("QS_STATE_DIR", None)
    env["XDG_STATE_HOME"] = str(output / "data-state")
    preference_dir = output / "data-state/quickshell-desktop"
    preference_dir.mkdir(parents=True, mode=0o700)
    aliases = output / "data-state/quickshell"
    aliases.mkdir()
    (aliases / "desktop").symlink_to(bundle, target_is_directory=True)
    env["DBUS_SYSTEM_BUS_ADDRESS"] = env["DBUS_SESSION_BUS_ADDRESS"]
    env["CLIPHIST_DB_PATH"] = str(output / "cache/cliphist/interaction-db")
    run(["swaymsg", "output", "HEADLESS-1", "resolution", "1920x1080"])
    log_path = output / "interactions.log"
    log_file = log_path.open("w")
    process = subprocess.Popen(["quickshell", "--path", str(fixture), "--no-color"], env=env,
                               stdout=log_file, stderr=subprocess.STDOUT)
    processes.append(process)

    def qa(method, *args):
        return run(["quickshell", "ipc", "--path", str(fixture), "call", "qa", method, *map(str, args)])

    def inspect():
        return json.loads(qa("inspect").stdout)

    def button(title):
        return next(b for b in inspect()["buttons"] if b["title"] == title)

    mouse_position = [0, 0]

    def point(x, y):
        mouse_position[:] = [round(x), round(y)]
        qa("point", *mouse_position)

    def click():
        qa("click", *mouse_position)

    def capture(name):
        time.sleep(0.2)
        run(["grim", str(output / (name + ".png"))])

    wait(lambda: "target qa" in run(["quickshell", "ipc", "--path", str(fixture), "show"], check=False).stdout)
    for title, name in [("Memory", "tooltip-memory"), ("Power & controls", "tooltip-screen-edge")]:
        control = button(title)
        point(control["x"], control["y"])
        wait(lambda: button(title)["tip"]["visible"], seconds=5)
        tip = button(title)["tip"]
        assert tip["height"] > 40 and tip["width"] <= 352, tip
        assert tip["position"]["y"] >= settings["bar"]["height"] + settings["bar"]["margin"], tip
        assert tip["position"]["x"] >= 0 and tip["position"]["x"] + tip["width"] <= 1920, tip
        (output / (name + "-state.json")).write_text(json.dumps(inspect(), indent=2))
        capture(name)
    click()
    wait(lambda: inspect()["menu"] == "power")
    state = inspect()
    assert state["card"]["y"] >= settings["bar"]["height"] + settings["bar"]["margin"]
    assert state["card"]["x"] + state["card"]["width"] <= 1920
    assert not button("Power & controls")["tip"]["visible"]
    capture("bar-power-panel")
    run(["wtype", "-s", "150", "-k", "Escape"])
    point(700, 350)
    wait(lambda: inspect()["menu"] == "")
    control = button("Power & controls")
    assert not control["visualFocus"] and not control["selected"] and control["borderAlpha"] == 0, control
    capture("bar-after-click")

    def key(name):
        run(["wtype", "-s", "80", "-k", name])

    def query(text):
        # Allow the new virtual keyboard's focus event to reach Qt before
        # sending modifiers, just as the other wtype calls do.
        run(["wtype", "-s", "150", "-M", "ctrl", "-k", "l", "-m", "ctrl", "-s", "80", "-k", "BackSpace", "-d", "10", text])
        wait(lambda: inspect()["query"] == text)

    qa("openControls")
    wait(lambda: inspect()["menu"] == "controls")
    time.sleep(0.2)
    capture("controls-home")
    query("dnd")
    wait(lambda: [r["id"] for r in inspect()["rows"]] == ["dnd"])
    initial_dnd = inspect()["dnd"]
    key("Return")
    wait(lambda: inspect()["dnd"] != initial_dnd)
    assert inspect()["selected"] == "dnd"
    capture("controls-dnd")
    key("Return")
    wait(lambda: inspect()["dnd"] == initial_dnd)
    saved_preferences = preference_dir / "state.json"
    wait(lambda: saved_preferences.exists() and json.loads(saved_preferences.read_text())["dnd"] == initial_dnd)
    assert not (bundle / "state.json").exists(), "Preferences were written into the configuration bundle"

    query("brightness")
    wait(lambda: bool(inspect()["rows"]) and inspect()["rows"][0]["value"] == "50%")
    key("Right")
    key("Right")
    key("Left")
    wait(lambda: bool(inspect()["rows"]) and inspect()["rows"][0]["value"] == "55%")
    assert inspect()["selected"] == "brightness"
    capture("controls-brightness")

    query("wifi")
    key("Return")
    wait(lambda: inspect()["menu"] == "wifi")
    key("Escape")
    wait(lambda: inspect()["menu"] == "controls")
    assert inspect()["query"] == "wifi" and inspect()["selected"] == "wifi"

    query("calendar")
    key("Return")
    wait(lambda: inspect()["menu"] == "calendar")
    month = inspect()["calendarMonth"]
    key("Right")
    wait(lambda: inspect()["calendarMonth"] == (month + 1) % 12)
    key("Home")
    wait(lambda: inspect()["calendarMonth"] == month)
    key("Escape")
    wait(lambda: inspect()["menu"] == "controls")

    qa("addNotification")
    query("notification history")
    key("Return")
    wait(lambda: inspect()["menu"] == "notifications" and inspect()["dndFocused"])
    key("Return")
    wait(lambda: inspect()["dnd"] != initial_dnd)
    key("Return")
    wait(lambda: inspect()["dnd"] == initial_dnd)
    key("Tab")
    key("Return")  # Clear history, via the actual focused button.
    wait(lambda: inspect()["notificationCount"] == 0)
    capture("controls-notification-keyboard")
    key("Escape")
    wait(lambda: inspect()["menu"] == "controls")

    query("restart")
    key("Return")
    wait(lambda: inspect()["confirmation"] == "reboot")
    assert inspect()["cancelFocused"] and inspect()["cancelVisualFocus"] and inspect()["requestedPower"] == ""
    capture("controls-confirmation")
    key("Return")  # A second Enter defaults to Cancel, never to reboot.
    wait(lambda: inspect()["confirmation"] == "")
    assert inspect()["requestedPower"] == ""
    key("Return")
    wait(lambda: inspect()["confirmation"] == "reboot")
    key("Tab")
    key("Return")  # The fixture records the signal; it cannot power off the host.
    wait(lambda: inspect()["requestedPower"] == "reboot" and inspect()["menu"] == "")
    print("Controls search, live DND/brightness, submenu history, calendar, notification focus and power confirmation passed")

    # The actual panel controls run against private service fixtures; keyboard
    # input exercises sliders, routing, radio, credentials and power profiles.
    qa("openPanel", "audio")
    wait(lambda: inspect()["menu"] == "audio")
    time.sleep(0.2)
    key("Right")
    wait(lambda: abs(inspect()["outputVolume"] - 0.55) < .001)
    key("Tab")
    key("Return")
    wait(lambda: inspect()["outputMuted"])
    key("Tab")
    key("Tab")
    key("Return")
    wait(lambda: inspect()["outputName"] == "qa-headphones")
    key("Tab")
    key("Left")
    wait(lambda: abs(inspect()["inputVolume"] - 0.75) < .001)
    capture("settings-audio")
    key("Escape")

    qa("openPanel", "wifi")
    wait(lambda: inspect()["menu"] == "wifi")
    time.sleep(0.2)
    key("Return")
    wait(lambda: not inspect()["wifiEnabled"])
    key("Return")
    wait(lambda: inspect()["wifiEnabled"])
    qa("networkState", "false", "false")
    state = inspect()
    assert state["wifiBackendWarning"] and not state["wifiHardwareWarning"]
    assert not state["wifiRadioEnabled"]
    capture("settings-wifi-backend-unavailable")
    qa("networkState", "true", "false")
    state = inspect()
    assert state["wifiHardwareWarning"] and not state["wifiBackendWarning"]
    assert not state["wifiRadioEnabled"]
    qa("networkState", "true", "true")
    qa("focusControl", "wifiRadio")
    key("Tab")
    key("Tab")
    key("Return")
    wait(lambda: inspect()["dnsPreset"] == "cloudflare")
    capture("settings-wifi")
    qa("selectGuestWifi")
    wait(lambda: inspect()["focused"] == "wifiPassword")
    key("Escape")
    assert inspect()["menu"] == "wifi" and not inspect()["wifiPassword"]
    qa("selectGuestWifi")
    wait(lambda: inspect()["focused"] == "wifiPassword")
    run(["wtype", "-s", "150", "test-password", "-k", "Return"])
    wait(lambda: inspect()["wifiPassword"])
    key("Escape")

    qa("openPanel", "battery")
    wait(lambda: inspect()["menu"] == "battery")
    time.sleep(0.2)
    key("Tab")
    key("Return")
    wait(lambda: inspect()["powerProfile"] == 2)
    assert inspect()["menu"] == "battery", "Profile selection unexpectedly closed the panel"
    capture("settings-battery")
    key("Escape")

    qa("openPanel", "display")
    wait(lambda: inspect()["menu"] == "display")
    time.sleep(0.2)
    key("Right")
    wait(lambda: (output / "brightnessctl.state").read_text() == "60")
    key("Tab")
    key("Right")
    wait(lambda: inspect()["panelTextSize"] == 15)
    key("Left")
    wait(lambda: inspect()["panelTextSize"] == 14)
    capture("settings-display")
    key("Tab")  # selected monitor
    key("Tab")  # 1x
    key("Tab")  # 1.25x
    key("Return")
    wait(lambda: inspect()["scaleBusy"] and inspect()["focused"] == "revertScale")
    key("Return")  # initial focus is Revert
    wait(lambda: not inspect()["scaleBusy"])
    assert inspect()["savedScale"] == 1
    # Start another preview through keyboard navigation, then explicitly keep.
    wait(lambda: inspect()["focused"] == "displayBrightnessSlider")
    key("Tab")
    key("Tab")
    key("Tab")
    key("Tab")
    key("Return")
    wait(lambda: inspect()["scaleBusy"] and inspect()["focused"] == "revertScale")
    key("Tab")
    key("Return")
    wait(lambda: not inspect()["scaleBusy"] and inspect()["savedScale"] == 1.25)
    key("Escape")
    run(["swaymsg", "output", "HEADLESS-1", "resolution", "1024x768"])
    qa("openPanel", "audio")
    time.sleep(0.2)
    for _ in range(8):
        key("Tab")
    capture("settings-compact-keyboard")
    key("Escape")
    run(["swaymsg", "output", "HEADLESS-1", "resolution", "1920x1080"])
    print("Audio sliders/routing, Wi-Fi radio/DNS/passwords, battery profiles and display keyboard controls passed")

    # Decode actual text and PNG history entries through the UI and packaged helper.
    payloads = [("text", "  Clipboard 中文 regression\nsecond line  \n".encode()),
                ("image", (output / "apps.png").read_bytes())]
    for kind, payload in payloads:
        subprocess.run([settings["bin"]["cliphist"], "store"], input=payload, env=env, check=True)
        qa("openClipboard")
        time.sleep(0.4)
        capture("clipboard-" + kind)
        run(["wtype", "-s", "150", "-k", "Return"])
        wait(lambda: inspect()["menu"] == "")
        restored = subprocess.run(["wl-paste", "--no-newline"], env=env, capture_output=True, check=True).stdout
        assert restored == payload, f"{kind} clipboard bytes changed"
        if kind == "image":
            assert "image/png" in run(["wl-paste", "--list-types"]).stdout

    # A stale selection must leave the existing clipboard intact and stay open.
    subprocess.run([settings["bin"]["cliphist"], "store"], input=b"Entry removed while picker is open", env=env, check=True)
    entry_id = run([settings["bin"]["cliphist"], "list"]).stdout.split("\t", 1)[0]
    qa("openClipboard")
    time.sleep(0.4)
    subprocess.run([settings["bin"]["cliphist"], "delete"], input=entry_id.encode(), env=env, check=True)
    run(["wtype", "-s", "150", "-k", "Return"])
    wait(lambda: bool(inspect()["message"]))
    assert inspect()["menu"] == "clipboard"
    assert subprocess.run(["wl-paste", "--no-newline"], env=env, capture_output=True, check=True).stdout == payloads[-1][1]
    assert not list(runtime.glob("quickshell-clipboard.*")), "Clipboard temporary file leaked"
    capture("clipboard-error")
    run(["wtype", "-s", "150", "-k", "Escape"])
    qa("report")
    assert not inspect()["osdProgress"]
    capture("message-toast")
    log = log_path.read_text()
    assert not re.search(r"TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign|Cannot assign|is not a function", log), log
    assert process.poll() is None
    print("Anchored tooltips/panels, mouse focus, text/PNG clipboard and stale-entry recovery passed")

try:
    bus = run(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"]).stdout.splitlines()
    env["DBUS_SESSION_BUS_ADDRESS"] = bus[0]
    env["DBUS_SYSTEM_BUS_ADDRESS"] = bus[0]
    bus_pid = int(bus[1])
    compositor_log = (output / "compositor.log").open("w")
    compositor = subprocess.Popen(["sway", "--config", str(output / "sway.conf")], env=env, stdout=compositor_log, stderr=subprocess.STDOUT)
    processes.append(compositor)
    wait(lambda: (runtime / "wayland-1").exists())
    env["WAYLAND_DISPLAY"] = "wayland-1"
    env["SWAYSOCK"] = str(next(runtime.glob("sway-ipc.*.sock")))
    shell_log = (output / "shell.log").open("w")
    shell = subprocess.Popen(["quickshell", "--config", "desktop", "--no-color"], env=env, stdout=shell_log, stderr=subprocess.STDOUT)
    processes.append(shell)
    def ipc(*args):
        # Match the production service and generated keybindings.
        return run(["quickshell", "ipc", "--config", "desktop", *args])
    wait(lambda: "target menus" in run(["quickshell", "ipc", "--config", "desktop", "show"], check=False).stdout)
    # A preview must not take ownership of desktop-wide authentication/notification services.
    assert "target session" not in ipc("show").stdout
    names = run(["dbus-send", "--session", "--print-reply", "--dest=org.freedesktop.DBus", "/", "org.freedesktop.DBus.ListNames"]).stdout
    assert '"org.freedesktop.Notifications"' not in names
    for target, method in [("audio", "volume"), ("audio", "microphone"), ("display", "brightness"), ("display", "temperature")]:
        # Exercise the actual CLI grammar used by decrease-volume/brightness keys.
        result = ipc("call", target, method, "-5")
        assert "error" not in (result.stdout + result.stderr).lower()
    menu_names = ["controls", "display", "desktop", "capture", "settings", "workspaces", "tray", "apps", "clipboard", "files", "vim", "lazyvim", "todos", "audio", "wifi", "bluetooth", "battery", "power", "powerProfiles", "notifications", "calendar", "status"]
    for menu in menu_names:
        ipc("call", "menus", "toggle", menu)
        time.sleep(0.3)
        run(["grim", str(output / (menu + ".png"))])
        run(["wtype", "-s", "150", "-k", "Escape"])
        wait(lambda: ipc("call", "menus", "current").stdout.strip()=="")
    ipc("call", "menus", "toggle", "apps")
    run(["wtype", "-s", "150", "-d", "20", "QA Fixture", "-k", "Return"])
    wait(lambda: ipc("call", "menus", "current").stdout.strip()=="")
    ipc("call", "menus", "toggle", "apps")
    run(["wtype", "-s", "150", "-d", "20", "zz-no-app-matches-zz"])
    run(["wtype", "-s", "150", "-k", "Return"])
    assert ipc("call", "menus", "current").stdout.strip()=="apps"
    time.sleep(0.2)
    run(["grim", str(output / "search-empty.png")])
    run(["wtype", "-s", "150", "-k", "Escape"])
    wait(lambda: ipc("call", "menus", "current").stdout.strip()=="")
    run(["swaymsg", "create_output"])
    run(["swaymsg", "output", "HEADLESS-2", "resolution", "1280x800"])
    run(["swaymsg", "output", "HEADLESS-2", "scale", "1.5"])
    time.sleep(0.5)
    run(["grim", str(output / "two-displays.png")])
    run(["swaymsg", "output", "HEADLESS-2", "disable"])
    run(["swaymsg", "output", "HEADLESS-1", "resolution", "1024x768"])
    time.sleep(0.3)
    run(["grim", str(output / "compact.png")])
    log = (output / "shell.log").read_text()
    failures = [line for line in log.splitlines() if re.search(r"TypeError|ReferenceError|Binding loop|Failed to load configuration|Unable to assign|Cannot assign|is not a function", line)]
    assert not failures, "\n".join(failures)
    assert shell.poll() is None
    shell.terminate()
    shell.wait(timeout=5)
    interaction_checks()
    (output / "result.json").write_text(json.dumps({"passed": True, "menus": len(menu_names), "settingsPanelsKeyboard": True, "wifiCredentials": True, "scaleConfirmation": True, "controlsKeyboard": True, "powerConfirmation": True, "multiMonitor": True, "scaledMonitor": True, "previewIsolation": True, "tooltips": True, "mouseFocus": True, "clipboardTextAndImage": True, "clipboardStaleEntry": True}, indent=2))
    print(f"{len(menu_names)} menus, keyboard search/Escape, monitor hotplug/scaling and preview isolation passed")
except Exception:
    fixture_path = output / "interactions.qml"
    if fixture_path.exists():
        diagnostic = run(["quickshell", "ipc", "--path", str(fixture_path), "call", "qa", "inspect"], check=False)
        print("Interaction state at failure:", diagnostic.stdout, flush=True)
        run(["grim", str(output / "failure.png")], check=False)
    raise
finally:
    for process in reversed(processes):
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    if "bus_pid" in locals():
        try:
            os.kill(bus_pid, 15)
        except ProcessLookupError:
            pass
