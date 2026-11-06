"""Chooser transport, literal paths, cancellation and private temp cleanup."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = str(Path(sys.argv.pop(1)).resolve())


class ImportTests(unittest.TestCase):
    def test_chooser_results_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            image = str(root / "image #%, ;? [one]\n.PNG")
            env = dict(os.environ, XDG_RUNTIME_DIR=directory, HOME=directory,
                       PATH=directory + os.pathsep + os.environ["PATH"],
                       IMAGE=image)
            kitty = root / "kitty"
            kitty.write_text("#!" + sys.executable + "\n" + '''import os, pathlib, sys
assert sys.argv[1:3] == ['--class', 'wallpaper-import']
assert sys.argv[5:8] == ['-e', 'superfile', '--chooser-file']
assert sys.argv[-1] == os.environ['HOME']
if not os.environ.get('CANCEL'):
    pathlib.Path(sys.argv[8]).write_text(os.environ['IMAGE'])
''')
            quickshell = root / "quickshell-wallpaper-dialog"
            quickshell.write_text("#!" + sys.executable + "\n" + '''import json, os, pathlib, sys
assert sys.argv[1:] == [os.environ['HOME']]
print(json.dumps({'paths': [] if os.environ.get('CANCEL') else [os.environ['IMAGE']], 'folder': os.environ['HOME']}))
''')
            kitty.chmod(0o700)
            quickshell.chmod(0o700)
            for mode in ("superfile", "dialog"):
                for cancel in (False, True):
                    with self.subTest(mode=mode, cancel=cancel):
                        run_env = dict(env, **({"CANCEL": "1"} if cancel else {}))
                        result = subprocess.run(["bash", SCRIPT, mode, str(root / "missing")],
                                                env=run_env, capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        self.assertEqual(json.loads(result.stdout)["paths"], [] if cancel else [image])
                        self.assertEqual(list(root.glob("wallpaper-import.*")), [])


if __name__ == "__main__":
    unittest.main()
