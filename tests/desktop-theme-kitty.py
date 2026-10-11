"""Check repeated theme switches against the packaged Kitty's real color cache."""

import os
from pathlib import Path
import subprocess
import sys

import kitty.colors


script = sys.argv[1]
root = Path(os.environ["DESKTOP_THEME_ROOT"])
state = Path(os.environ["DESKTOP_THEME_STATE"])
config = Path(os.environ["TMPDIR"]) / "kitty-config"
config.mkdir()
for appearance in ["dark", "light", "no-preference"]:
    (config / f"{appearance}-theme.auto.conf").symlink_to(state / "kitty.conf")

kitty.colors.config_dir = str(config)
cache = kitty.colors.ThemeColors()
themes = subprocess.check_output(["bash", script, "list"], text=True).splitlines()

# Keep the cache alive across switches, including a return to a previous asset.
for theme in themes + themes[:1]:
    subprocess.run(["bash", script, "set", theme], check=True, stdout=subprocess.DEVNULL)
    # Kitty's embedded Python runs with assertions disabled.
    if not cache.refresh():
        raise AssertionError(f"Kitty did not refresh its cached colors for {theme}")
    source = root / theme / "kitty.conf"
    if (state / "kitty.conf").read_bytes() != source.read_bytes():
        raise AssertionError(f"Kitty's published colors differ from the {theme} asset")
    expected = {}
    for line in source.read_text().splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] in ["background", "foreground"]:
            expected[parts[0]] = int(parts[1].removeprefix("#"), 16)
    for appearance in ["dark", "light", "no_preference"]:
        colors = getattr(cache, f"{appearance}_spec")
        for key, value in expected.items():
            if colors[key] != value:
                raise AssertionError(f"Stale {appearance} {key} for {theme}")

print(f"Kitty's persistent automatic color cache follows all {len(themes)} themes")
