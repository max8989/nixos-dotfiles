"""Exercise enrollment failures without contacting the real fingerprint reader."""
import os
import pathlib
import subprocess
import sys
import tempfile

script = pathlib.Path(sys.argv[1]).resolve()
user = subprocess.check_output(["id", "-un"], text=True).strip()
with tempfile.TemporaryDirectory() as directory:
    root = pathlib.Path(directory)
    log = root / "calls"
    for action in ["enroll", "verify", "list"]:
        executable = root / f"fprintd-{action}"
        executable.write_text(
            '#!/bin/sh\n'
            f'printf "%s\\n" "{action}:$*" >> "$FINGERPRINT_TEST_LOG"\n'
            f'exit "${{FINGERPRINT_TEST_{action.upper()}_STATUS:-0}}"\n'
        )
        executable.chmod(0o755)

    def run(action, **overrides):
        log.write_text("")
        result = subprocess.run(
            ["bash", "-euo", "pipefail", str(script), action],
            stdin=subprocess.DEVNULL, capture_output=True, text=True,
            env={**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"],
                 "FINGERPRINT_TEST_LOG": str(log), **overrides},
        )
        return result, log.read_text().splitlines()

    result, calls = run("setup")
    assert result.returncode == 0 and calls == [f"enroll:{user}", f"verify:{user}"]
    assert "Fingerprint verified" in result.stdout
    result, calls = run("setup", FINGERPRINT_TEST_ENROLL_STATUS="7")
    assert result.returncode == 7 and calls == [f"enroll:{user}"]
    assert "Fingerprint verified" not in result.stdout
    result, calls = run("setup", FINGERPRINT_TEST_VERIFY_STATUS="8")
    assert result.returncode == 8 and calls == [f"enroll:{user}", f"verify:{user}"]
    assert "Fingerprint verified" not in result.stdout
    for action in ["verify", "list"]:
        result, calls = run(action)
        assert result.returncode == 0 and calls == [f"{action}:{user}"]
    result, calls = run("invalid")
    assert result.returncode == 2 and calls == []
print("Fingerprint setup, verification, listing and failure handling passed")
