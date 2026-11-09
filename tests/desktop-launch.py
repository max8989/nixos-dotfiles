"""Check launcher policy/argument boundaries without starting user applications."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    capture = root / "arguments.json"
    stub = root / "app2unit"
    stub.write_text(f"#!{sys.executable}\nimport json,os,sys\n"
                    "json.dump(sys.argv[1:],open(os.environ['CAPTURE'],'w'))\n"
                    "sys.exit(int(os.environ.get('LAUNCH_EXIT','0')))\n")
    stub.chmod(0o755)
    env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}", CAPTURE=str(capture))

    def launch(*args, code=0, **extra_env):
        capture.unlink(missing_ok=True)
        result = subprocess.run(["bash", str(script), *args], env=env | extra_env,
                                capture_output=True, text=True)
        assert result.returncode == code, (args, result.returncode, result.stderr)
        return json.loads(capture.read_text()) if capture.exists() else None

    for app in ["firefox", "/nix/store/example/bin/google-chrome", "zen-beta.desktop",
                "dev.zed.Zed.desktop", "org.kde.kate.desktop", "com.google.Chrome.desktop",
                "kitty", "kitty-open.desktop", "nvim.desktop", "firefox.desktop:new-window"]:
        args = launch("--", app)
        assert "ManagedOOMPreference=avoid" in args, (app, args)
        assert args[-2:] == ["--", app]
    assert "ManagedOOMPreference=none" in launch("--", "spotify")
    assert "ManagedOOMPreference=none" in launch("--normal", "--", "firefox")
    assert "ManagedOOMPreference=avoid" in launch("--important", "--", "sleep", "30")
    payload = ["file with spaces", "$(touch should-not-exist)", "", "--important", "a'b"]
    args = launch("--", "test-command", *payload)
    assert args[-len(payload):] == payload
    assert args[:4] == ["-t", "scope", "-s", "app.slice"]
    args = launch("--open", "--", "https://example.test/?q=a&b=2")
    assert "-O" in args and "ManagedOOMPreference=avoid" in args
    launch("--", "test-command", code=23, LAUNCH_EXIT="23")
    for args in [(), ("--bogus",), ("--",), ("--open", "--")]:
        assert launch(*args, code=2) is None
print("Desktop launch priority, arguments, open mode and failures passed")
