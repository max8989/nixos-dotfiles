"""Exercise wallpaper persistence and display updates without a live session."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPT = str(Path(sys.argv.pop(1)).resolve())


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.themes = self.root / "themes"
        self.state = self.root / "state"
        self.calls = self.root / "hyprctl.jsonl"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, DESKTOP_THEME_ROOT=str(self.themes),
                        DESKTOP_THEME_STATE=str(self.state),
                        HYPRLAND_INSTANCE_SIGNATURE="wallpaper-test",
                        DBUS_SESSION_BUS_ADDRESS="",
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.make_themes(self.themes)
        hyprctl = self.bin / "hyprctl"
        hyprctl.write_text("#!" + sys.executable + "\n" + f"""
import json, sys
with open({str(self.calls)!r}, 'a') as log:
    print(json.dumps(sys.argv[1:]), file=log)
if sys.argv[1:] == ['-j', 'monitors']:
    print('[{{"name":"eDP-1"}},{{"name":"DP-2"}}]')
elif sys.argv[1:] == ['-j', 'clients']:
    print('[]')
""")
        hyprctl.chmod(0o700)
        for command in ("quickshell", "notify-send", "systemctl"):
            path = self.bin / command
            path.write_text("#!/bin/sh\nexit 0\n")
            path.chmod(0o700)
        self.image = self.root / "wallpaper [one] #%, ;.PNG"
        shutil.copyfile(self.themes / "nord/wallpaper.png", self.image)

    def make_themes(self, root):
        root.mkdir()
        catalog = {"order": ["tokyo-night", "nord"], "themes": {}}
        for name, color in (("tokyo-night", "red"), ("nord", "blue")):
            folder = root / name
            folder.mkdir()
            (folder / "kitty.conf").write_text("background #000000\n")
            subprocess.run(["magick", "-size", "4x3", "xc:" + color,
                            str(folder / "wallpaper.png")], check=True)
            catalog["themes"][name] = {"mode": "dark", "iconTheme": "Adwaita"}
        (root / "catalog.json").write_text(json.dumps(catalog))

    def run_theme(self, *args, success=True):
        result = subprocess.run(["bash", SCRIPT, *map(str, args)], env=self.env,
                                capture_output=True, text=True, timeout=15)
        if success:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result.stdout.strip()

    def display_calls(self):
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        return [call for call in calls if call[:2] == ["hyprpaper", "wallpaper"]]

    def assert_active(self, theme, wallpaper):
        self.assertEqual(self.run_theme("current"), theme)
        self.assertEqual((self.state / "current").resolve(), Path(self.env["DESKTOP_THEME_ROOT"]) / theme)
        self.assertEqual((self.state / "wallpaper.png").resolve(), Path(wallpaper))
        self.assertEqual(self.display_calls()[-2:], [
            ["hyprpaper", "wallpaper", f"{monitor}, {wallpaper}"]
            for monitor in ("eDP-1", "DP-2")])

    def test_defaults_work_before_and_after_first_activation(self):
        default = self.themes / "tokyo-night/wallpaper.png"
        self.assertEqual(self.run_theme("wallpaper", "current"), str(default))
        self.assertFalse(self.state.exists())
        self.run_theme("reconcile")
        self.assert_active("tokyo-night", default)

    def test_each_theme_restores_its_copy_after_source_is_moved(self):
        self.run_theme("reconcile")
        tokyo = self.run_theme("wallpaper", "set", self.image)
        self.assertTrue(Path(tokyo).is_relative_to(self.state))
        self.assertEqual(Path(tokyo).stat().st_mode & 0o777, 0o600)
        self.image.unlink()
        self.run_theme("set", "nord")
        self.assert_active("nord", self.themes / "nord/wallpaper.png")
        nord = self.run_theme("wallpaper", "set", self.themes / "tokyo-night/wallpaper.png")
        self.assertNotEqual(tokyo, nord)
        self.run_theme("set", "tokyo-night")
        self.assert_active("tokyo-night", tokyo)
        self.run_theme("set", "nord")
        self.run_theme("reconcile")
        self.assert_active("nord", nord)

    def test_setting_an_inactive_theme_does_not_change_the_display(self):
        self.run_theme("reconcile")
        before = self.display_calls()
        saved = self.run_theme("wallpaper", "set", self.image, "nord")
        self.assertEqual(self.display_calls(), before)
        self.assertEqual(self.run_theme("wallpaper", "current", "nord"), saved)
        self.assert_active("tokyo-night", self.themes / "tokyo-night/wallpaper.png")
        self.run_theme("set", "nord")
        self.assert_active("nord", saved)

    def test_reset_only_changes_the_requested_theme(self):
        self.run_theme("reconcile")
        tokyo = self.run_theme("wallpaper", "set", self.image)
        self.run_theme("wallpaper", "set", self.image, "nord")
        before = self.display_calls()
        self.run_theme("wallpaper", "reset", "nord")
        self.assertEqual(self.display_calls(), before)
        self.assert_active("tokyo-night", tokyo)
        self.run_theme("wallpaper", "reset")
        self.assert_active("tokyo-night", self.themes / "tokyo-night/wallpaper.png")
        self.run_theme("set", "nord")
        self.assert_active("nord", self.themes / "nord/wallpaper.png")

    def test_bad_inputs_preserve_the_saved_selection(self):
        self.run_theme("reconcile")
        saved = self.run_theme("wallpaper", "set", self.image)
        corrupt = self.root / "corrupt.png"
        corrupt.write_text("not an image")
        unsupported = self.root / "wallpaper.svg"
        shutil.copyfile(self.image, unsupported)
        for args in [("set", corrupt), ("set", unsupported),
                     ("set", self.root / "missing.jpg"), ("set", self.root),
                     ("set", self.image, "../nord"), ("set", self.image, "unknown"),
                     ("current", "../nord"), ("reset", "../nord"), ("set",)]:
            with self.subTest(args=args):
                self.run_theme("wallpaper", *args, success=False)
                self.assertEqual(self.run_theme("wallpaper", "current"), saved)
                self.assert_active("tokyo-night", saved)
        self.assertEqual(list(self.state.glob(".wallpaper.*")), [])

    def test_rebuild_reconciles_new_assets_and_preserves_custom_wallpaper(self):
        self.run_theme("reconcile")
        saved = self.run_theme("wallpaper", "set", self.image)
        new_root = self.root / "rebuilt-themes"
        self.make_themes(new_root)
        self.env["DESKTOP_THEME_ROOT"] = str(new_root)
        self.run_theme("reconcile")
        self.assert_active("tokyo-night", saved)
        self.run_theme("wallpaper", "reset")
        self.assert_active("tokyo-night", new_root / "tokyo-night/wallpaper.png")

    def test_missing_saved_image_falls_back_to_theme_default(self):
        self.run_theme("reconcile")
        saved = self.run_theme("wallpaper", "set", self.image)
        Path(saved).unlink()
        self.run_theme("reconcile")
        self.assert_active("tokyo-night", self.themes / "tokyo-night/wallpaper.png")

    def test_supported_raster_formats_are_normalized_to_png(self):
        self.run_theme("reconcile")
        for extension in ("jpg", "JPEG", "webp", "BMP"):
            with self.subTest(extension=extension):
                image = self.root / ("photo." + extension)
                subprocess.run(["magick", str(self.image), str(image)], check=True)
                saved = Path(self.run_theme("wallpaper", "set", image))
                self.assertEqual(saved.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
                self.assert_active("tokyo-night", saved)

    def test_browser_lists_directories_and_supported_images_with_literal_paths(self):
        folder = self.root / "Pictures #%, ;?"
        folder.mkdir()
        (folder / "nested directory").mkdir()
        image = folder / self.image.name
        shutil.copyfile(self.image, image)
        (folder / "ignored.txt").write_text("not a wallpaper")
        shutil.copyfile(self.image, folder / ".hidden.png")
        (folder / "linked photo.png").symlink_to(image)
        entries = json.loads(self.run_theme("wallpaper", "list", folder))
        self.assertEqual([entry["name"] for entry in entries], [
            "nested directory", "linked photo.png", self.image.name])
        self.assertTrue(entries[0]["directory"])
        self.assertFalse(entries[-1]["directory"])
        self.assertEqual(entries[-1]["path"], str(image))
        self.assertFalse(self.state.exists(), "Browsing must not change theme state")
        self.run_theme("wallpaper", "list", image, success=False)


if __name__ == "__main__":
    unittest.main()
