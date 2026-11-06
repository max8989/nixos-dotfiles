"""Exercise the recording controller with isolated display/audio boundaries."""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPTS = Path(sys.argv.pop(1)).resolve()
BASH = shutil.which("bash")
STUB = r'''
import json, os, signal, sys, time
from pathlib import Path
root = Path(os.environ["RECORD_FIXTURE"])
name, args = Path(sys.argv[0]).name, sys.argv[1:]
with (root / "calls").open("a") as log:
    log.write(json.dumps([name, args]) + "\n")
if name == "hyprctl":
    print('[{"name":"DP-1","focused":true}]')
elif name == "nixos-capture-region":
    if os.environ.get("PICKER_CANCEL") == "1": sys.exit(1)
    if os.environ.get("PICKER_BLOCK") == "1":
        (root / "picking").touch()
        time.sleep(30)
    print("-100,20 301x201")
elif name == "pactl":
    if os.environ.get("AUDIO_FAIL") == "1": sys.exit(1)
    if args == ["get-default-sink"]: print("speakers")
    elif args == ["get-default-source"]: print("microphone")
    elif args == ["--format=json", "list", "sinks"]:
        print('[{"name":"speakers","monitor_source":"speakers.monitor"}]')
    else: sys.exit(1)
elif name == "wf-recorder":
    if os.environ.get("RECORDER_FAIL") == "1": sys.exit(1)
    path = Path(args[args.index("-f") + 1])
    path.write_bytes(b"recording")
    def finish(*_):
        time.sleep(0.1)
        path.write_bytes(b"finalized video")
        sys.exit(0)
    signal.signal(signal.SIGINT, finish)
    (root / "recorder-pid").write_text(str(os.getpid()))
    time.sleep(30)
elif name == "sleep":
    if os.environ.get("COUNTDOWN_BLOCK") == "1":
        (root / "counting").touch()
        time.sleep(30)
    else: time.sleep(0.03)
elif name == "notify-send":
    if "--wait" in args:
        # The controller must only notify after the video has been finalized.
        video = next((root / "Videos with spaces").glob("*.mp4"))
        assert video.read_bytes() == b"finalized video"
        print(os.environ.get("NOTIFY_ACTION", ""))
elif name == "wl-copy":
    (root / "clipboard").write_bytes(sys.stdin.buffer.read())
elif name == "pgrep": sys.exit(1)
'''


class RecordingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="screen-record-qa-")
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("hyprctl", "nixos-capture-region", "pactl", "wf-recorder", "sleep",
                     "notify-send", "wl-copy", "xdg-open", "pgrep", "pkill"):
            path = self.bin / name
            path.write_text(f"#!{sys.executable}\n" + STUB)
            path.chmod(0o755)
        notifier = self.bin / "nixos-screen-record-notify"
        notifier.write_text(f"#!{BASH}\nexec {BASH} {SCRIPTS / 'screen-record-notify.sh'} \"$@\"\n")
        notifier.chmod(0o755)
        self.env = os.environ | {
            "PATH": str(self.bin) + ":" + os.environ["PATH"],
            "HOME": str(self.root / "home"),
            "XDG_RUNTIME_DIR": str(self.root / "runtime"),
            "NIXOS_SCREENRECORD_DIR": str(self.root / "Videos with spaces"),
            "RECORD_FIXTURE": str(self.root),
        }
        self.processes = []

    def tearDown(self):
        for process in self.processes:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        self.temp.cleanup()

    def run_record(self, *args, **changes):
        return subprocess.run([BASH, str(SCRIPTS / "screen_record.sh"), *args],
                              env=self.env | changes, capture_output=True, text=True, timeout=5)

    def start(self, *args, **changes):
        process = subprocess.Popen([BASH, str(SCRIPTS / "screen_record.sh"), *args],
                                   env=self.env | changes, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.processes.append(process)
        return process

    def wait_for(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate(): return
            time.sleep(0.02)
        self.fail("Timed out waiting for recording state")

    def calls(self, name):
        log = self.root / "calls"
        return [args for tool, args in map(json.loads, log.read_text().splitlines()) if tool == name] if log.exists() else []

    def status(self):
        result = self.run_record("--status")
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def recording(self, *args, **changes):
        process = self.start(*args, **changes)
        self.wait_for(lambda: (self.root / "recorder-pid").exists())
        return process

    def stop(self, process):
        self.assertEqual(self.run_record("--stop").returncode, 0)
        self.assertEqual(process.wait(timeout=5), 0)
        self.assertEqual(self.status(), {"active": False})

    def test_status_idle_and_stop_are_side_effect_free(self):
        self.assertEqual(self.status(), {"active": False})
        self.assertEqual(self.run_record("--stop").returncode, 0)
        self.assertFalse(self.calls("wf-recorder"))

    def test_fullscreen_toggle_finalizes_before_notifying(self):
        process = self.recording()
        state = self.status()
        self.assertTrue(state["active"])
        self.assertEqual((state["phase"], state["mode"], state["audio"]), ("recording", "fullscreen", "none"))
        self.assertEqual(self.run_record().returncode, 0)
        self.assertEqual(process.wait(timeout=5), 0)
        self.wait_for(lambda: any("--wait" in args for args in self.calls("notify-send")))
        self.assertEqual(Path(state["file"]).read_bytes(), b"finalized video")
        self.assertIn("DP-1", self.calls("wf-recorder")[0])
        self.assertFalse(any(arg.startswith("--audio") for arg in self.calls("wf-recorder")[0]))

    def test_selection_and_audio_sources(self):
        for mode, audio, source in [("region", "desktop", "speakers.monitor"),
                                    ("windows", "microphone", "microphone")]:
            with self.subTest(mode=mode, audio=audio):
                (self.root / "recorder-pid").unlink(missing_ok=True)
                process = self.recording(mode, audio)
                args = self.calls("wf-recorder")[-1]
                self.assertEqual(args[args.index("-g") + 1], "-100,20 301x201")
                self.assertIn("--audio=" + source, args)
                self.assertIn([mode, "--match-monitor"], self.calls("nixos-capture-region"))
                self.stop(process)

    def test_cancel_creates_no_recording(self):
        result = self.run_record("region", PICKER_CANCEL="1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.calls("wf-recorder"))
        self.assertFalse(list(self.root.glob("Videos with spaces/*.mp4")))
        self.assertEqual(self.status(), {"active": False})

    def test_stop_during_selection_and_countdown(self):
        for change, marker in [("PICKER_BLOCK", "picking"), ("COUNTDOWN_BLOCK", "counting")]:
            with self.subTest(change=change):
                process = self.start("region", **{change: "1"})
                self.wait_for(lambda: (self.root / marker).exists())
                self.stop(process)
                self.assertFalse(self.calls("wf-recorder"))

    def test_audio_failure_and_encoder_failure_clear_status(self):
        for changes in [{"AUDIO_FAIL": "1"}, {"RECORDER_FAIL": "1"}]:
            with self.subTest(changes=changes):
                result = self.run_record("fullscreen", "desktop", **changes)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.status(), {"active": False})
                self.assertFalse(list(self.root.glob("Videos with spaces/*.mp4")))
        self.assertFalse(any("--wait" in args for args in self.calls("notify-send")))

    def test_completion_actions(self):
        for action in ("open", "folder", "copy"):
            with self.subTest(action=action):
                (self.root / "recorder-pid").unlink(missing_ok=True)
                process = self.recording(NOTIFY_ACTION=action)
                path = self.status()["file"]
                self.stop(process)
                if action == "copy":
                    self.wait_for(lambda: (self.root / "clipboard").exists())
                    self.assertEqual((self.root / "clipboard").read_text(), path)
                else:
                    expected = path if action == "open" else str(Path(path).parent)
                    self.wait_for(lambda: [expected] in self.calls("xdg-open"))

    def test_stale_state_never_signals_an_unrelated_process(self):
        directory = Path(self.env["XDG_RUNTIME_DIR"]) / f"nixos-screen-record-{os.getuid()}"
        directory.mkdir(parents=True)
        (directory / "state.json").write_text(json.dumps({"pid": os.getpid(), "token": "stale"}))
        self.assertEqual(self.status(), {"active": False})
        self.assertEqual(self.run_record("--stop").returncode, 0)

    def test_invalid_arguments_do_not_start_recording(self):
        for args in [("bad-mode",), ("region", "bad-audio"), ("--status", "extra")]:
            self.assertEqual(self.run_record(*args).returncode, 2)
        self.assertFalse(self.calls("wf-recorder"))


unittest.main()
