"""Exercise capture/selection workflows without touching the developer's desktop."""
import base64
import json
import os
from pathlib import Path
import signal
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPTS = Path(sys.argv.pop(1)).resolve()
PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jkXcAAAAASUVORK5CYII=")

STUB = r'''
import json, os, signal, sys, time
from pathlib import Path
root = Path(os.environ["CAPTURE_FIXTURE"])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, args]) + "\n")
if name == "hyprctl":
    if args[0] == "monitors": print((root / "monitors").read_text())
    elif args[0] == "clients": print((root / "clients").read_text())
    elif args[0] == "cursorpos": print((root / "cursor").read_text())
    elif args[0] == "getoption": print('{"int":2}')
    elif args[0] == "eval": pass
    else: sys.exit(1)
elif name == "hyprpicker":
    (root / "freeze").write_text(str(os.getpid()))
    def stop(*_):
        (root / "freeze-stopped").touch()
        sys.exit(0)
    signal.signal(signal.SIGTERM, stop)
    time.sleep(30)
elif name == "slurp":
    mode = os.environ.get("PICKER", "pick")
    if "-r" in args:
        (root / "rectangles").write_text(sys.stdin.read())
    if mode == "cancel": sys.exit(1)
    if mode == "block": time.sleep(30); sys.exit(1)
    print(os.environ.get("PICKER_SELECTION", "20,30 300x200"))
elif name == "grim":
    if os.environ.get("GRIM_FAIL") == "1": sys.exit(1)
    data = (root / "image").read_bytes()
    if args[-1] == "-": sys.stdout.buffer.write(data)
    else: Path(args[-1]).write_bytes(data)
elif name == "wl-copy":
    data = sys.stdin.buffer.read()
    if os.environ.get("CLIPBOARD_FAIL") == "1": sys.exit(1)
    (root / "clipboard").write_bytes(data)
    if os.environ.get("CLIPBOARD_DAEMON") == "1":
        pid = os.fork()
        if pid == 0:
            # Keep inherited descriptors like the real clipboard owner, but
            # detach the pipes so subprocess.run can finish independently.
            with open(os.devnull, "r+b") as null:
                for fd in (0, 1, 2): os.dup2(null.fileno(), fd)
            time.sleep(30)
            os._exit(0)
        with (root / "clipboard-daemons").open("a") as pids:
            pids.write(str(pid) + "\n")
elif name in ("notify-send", "nixos-capture-notify"):
    if os.environ.get("NOTIFY_FAIL") == "1": sys.exit(1)
'''


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="capture-qa-")
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ["hyprctl", "hyprpicker", "slurp", "grim", "wl-copy", "notify-send", "nixos-capture-notify"]:
            p = self.bin / name
            p.write_text(f"#!{sys.executable}\n" + STUB)
            p.chmod(0o755)
        p = self.bin / "nixos-capture-region"
        p.write_text(f"#!{sys.executable}\nimport os\nos.execv({shutil.which('bash')!r}, [{shutil.which('bash')!r}, {str(SCRIPTS / 'capture-region.sh')!r}] + __import__('sys').argv[1:])\n")
        p.chmod(0o755)
        self.env = os.environ | {
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "HOME": str(self.root / "home"),
            "XDG_RUNTIME_DIR": str(self.root / "runtime"),
            "XDG_STATE_HOME": str(self.root / "state"),
            "NIXOS_SCREENSHOT_DIR": str(self.root / "Pictures with spaces"),
            "CAPTURE_FIXTURE": str(self.root),
        }
        self.monitors = [{"name": "DP-1", "focused": True, "x": -1920, "y": 0,
                          "width": 2400, "height": 1350, "scale": 1.25, "transform": 0,
                          "activeWorkspace": {"id": 1}}]
        self.clients = [{"workspace": {"id": 1}, "hidden": False, "at": [20, 30], "size": [300, 200]},
                        {"workspace": {"id": 1}, "hidden": False, "at": [100, 80], "size": [80, 60]},
                        {"workspace": {"id": 1}, "hidden": True, "at": [600, 0], "size": [300, 200]}]
        self.write_geometry()
        (self.root / "cursor").write_text("130, 100")
        (self.root / "image").write_bytes(PNG)
        (self.root / "clipboard").write_bytes(b"original clipboard")

    def tearDown(self):
        # Always reap the fake freeze if a failing test interrupted cleanup.
        self.run_region("--cancel", check=False)
        pids = self.root / "clipboard-daemons"
        if pids.exists():
            for pid in pids.read_text().splitlines():
                try: os.kill(int(pid), signal.SIGTERM)
                except ProcessLookupError: pass
        self.temp.cleanup()

    def write_geometry(self):
        (self.root / "monitors").write_text(json.dumps(self.monitors))
        (self.root / "clients").write_text(json.dumps(self.clients))

    def run_capture(self, *args, check=True, **changes):
        return subprocess.run([shutil.which("bash"), str(SCRIPTS / "screenshot.sh"), *args],
                              env=self.env | changes, capture_output=True, text=True,
                              check=check, timeout=10)

    def run_region(self, *args, check=True, **changes):
        return subprocess.run([str(self.bin / "nixos-capture-region"), *args],
                              env=self.env | changes, capture_output=True, text=True,
                              check=check, timeout=10)

    def calls(self, name):
        log = self.root / "calls"
        return [args for tool, args in map(json.loads, log.read_text().splitlines()) if tool == name] if log.exists() else []

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate(): return
            time.sleep(0.02)
        self.fail("Timed out waiting for capture state")

    def assert_clean(self):
        runtime = Path(self.env["XDG_RUNTIME_DIR"]) / f"nixos-capture-{os.getuid()}"
        self.assertFalse((runtime / "freeze.pid").exists())
        self.assertFalse((runtime / "slurp.pid").exists())
        self.assertFalse((runtime / "result").exists())
        cursor_calls = self.calls("hyprctl")
        self.assertIn(["eval", "hl.config({ cursor = { no_hardware_cursors = 2 } })"], cursor_calls)

    def test_save_copy_path_and_repeated_capture(self):
        result = self.run_capture("region")
        path = Path(result.stdout.strip())
        self.assertEqual(path.read_bytes(), PNG)
        self.assertEqual((self.root / "clipboard").read_bytes(), PNG)
        self.assertEqual(self.calls("wl-copy"), [["--type", "image/png"]])
        self.assertEqual((self.root / "state/nixos-capture/latest").read_text().strip(), str(path))
        self.assert_clean()
        self.assertNotEqual(self.run_capture("region").stdout.strip(), str(path))
        self.assert_clean()

    def test_cancel_preserves_clipboard_and_creates_no_image(self):
        self.assertEqual(self.run_capture("region", PICKER="cancel").stdout, "")
        self.assertEqual((self.root / "clipboard").read_bytes(), b"original clipboard")
        self.assertFalse(Path(self.env["NIXOS_SCREENSHOT_DIR"]).exists())
        self.assert_clean()

    def assert_repeated_capture_with_clipboard_owner_running(self, processing):
        first = self.run_capture("fullscreen", processing, CLIPBOARD_DAEMON="1")
        pid = int((self.root / "clipboard-daemons").read_text().splitlines()[-1])
        os.kill(pid, 0)
        second = self.run_capture("fullscreen", processing, CLIPBOARD_DAEMON="1")
        self.assertEqual(len(self.calls("grim")), 2)
        self.assertEqual((self.root / "clipboard").read_bytes(), PNG)
        if processing == "slurp":
            self.assertTrue(Path(second.stdout.strip()).is_file())
            self.assertNotEqual(first.stdout, second.stdout)
        self.assert_clean()

    def test_repeated_saved_capture_with_clipboard_owner_running(self):
        self.assert_repeated_capture_with_clipboard_owner_running("slurp")

    def test_repeated_copy_only_capture_with_clipboard_owner_running(self):
        self.assert_repeated_capture_with_clipboard_owner_running("copy")

    def test_capture_failure_removes_partial_file_and_restores_cursor(self):
        self.assertNotEqual(self.run_capture("region", check=False, GRIM_FAIL="1").returncode, 0)
        self.assertEqual(list(Path(self.env["NIXOS_SCREENSHOT_DIR"]).glob("*.png")), [])
        self.assertEqual((self.root / "clipboard").read_bytes(), b"original clipboard")
        self.assert_clean()

    def test_clipboard_failure_keeps_saved_file(self):
        result = self.run_capture("region", check=False, CLIPBOARD_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(Path(result.stdout.strip()).read_bytes(), PNG)
        self.assert_clean()

    def test_copy_only_and_save_only(self):
        self.run_capture("region", "copy")
        self.assertEqual((self.root / "clipboard").read_bytes(), PNG)
        self.assertFalse(Path(self.env["NIXOS_SCREENSHOT_DIR"]).exists())
        (self.root / "clipboard").write_bytes(b"keep me")
        self.assertTrue(Path(self.run_capture("region", "save").stdout.strip()).exists())
        self.assertEqual((self.root / "clipboard").read_bytes(), b"keep me")
        self.assert_clean()

    def test_focused_monitor_negative_position_and_scale(self):
        self.run_capture("fullscreen")
        self.assertEqual(self.calls("grim")[0][1], "-1920,0 1920x1080")
        self.assertFalse(self.calls("slurp"))
        self.assertFalse(self.calls("hyprpicker"))
        self.assert_clean()

    def test_rotated_and_flipped_monitors(self):
        for transform in [1, 3, 5, 7]:
            self.monitors[0]["transform"] = transform
            self.write_geometry()
            self.assertEqual(self.run_region("fullscreen").stdout.strip(), "-1920,0 1080x1920")

    def test_smart_click_selects_smallest_visible_window(self):
        self.run_capture("smart", PICKER_SELECTION="130,100 1x1")
        self.assertEqual(self.calls("grim")[0][1], "100,80 80x60")
        self.assert_clean()

    def test_window_picker_omits_hidden_and_duplicate_rectangles(self):
        self.clients.append(self.clients[0])
        self.write_geometry()
        self.run_capture("windows")
        rects = (self.root / "rectangles").read_text()
        self.assertEqual(rects.count("20,30 300x200"), 1)
        self.assertNotIn("600,0", rects)
        self.assert_clean()

    def test_keyboard_select_and_capture_highlighted_window(self):
        process = subprocess.Popen([str(self.bin / "nixos-capture-region"), "windows"],
                                   env=self.env | {"PICKER": "block"}, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            runtime = Path(self.env["XDG_RUNTIME_DIR"]) / f"nixos-capture-{os.getuid()}"
            self.wait_for(lambda: (runtime / "slurp.pid").exists())
            self.run_region("--select-window", "next")
            self.assertTrue(any("hl.dsp.cursor.move" in args[-1] for args in self.calls("hyprctl")))
            self.run_region("--take-window")
            out, err = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual(out.strip(), "100,80 80x60")
        finally:
            if process.poll() is None:
                self.run_region("--cancel")
                process.communicate(timeout=5)

    def test_second_shortcut_cancels_owned_picker(self):
        process = subprocess.Popen([shutil.which("bash"), str(SCRIPTS / "screenshot.sh"), "region"],
                                   env=self.env | {"PICKER": "block"}, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            runtime = Path(self.env["XDG_RUNTIME_DIR"]) / f"nixos-capture-{os.getuid()}"
            self.wait_for(lambda: (runtime / "slurp.pid").exists())
            self.assertEqual(self.run_capture("region").stdout, "")
            out, err = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual(out, "")
            self.assertEqual((self.root / "clipboard").read_bytes(), b"original clipboard")
            self.assert_clean()
        finally:
            if process.poll() is None:
                self.run_region("--cancel")
                process.communicate(timeout=5)


unittest.main(verbosity=2)
