"""Hardware-independent regressions for DNS transactions and scale recovery."""
import importlib.util
import io
import itertools
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("settings", sys.argv.pop(1))
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)


class SettingsTests(unittest.TestCase):
    def test_network_ready_retries_missing_and_unresponsive_daemon(self):
        replies = [settings.subprocess.CompletedProcess([], 1, "unknown\n"),
                   settings.subprocess.TimeoutExpired("nmcli", 1),
                   settings.subprocess.CompletedProcess([], 0, "running\n")]
        with patch.object(settings.subprocess, "run", side_effect=replies) as run, patch.object(settings.time, "sleep"):
            self.assertEqual(settings.network_ready(), {"ready": True})
        self.assertEqual(run.call_count, 3)
        self.assertEqual(run.call_args.args[0], [settings.NMCLI, "-g", "RUNNING", "general"])

    def test_network_ready_does_not_wait_for_wifi_or_internet(self):
        with patch.object(settings.subprocess, "run", return_value=settings.subprocess.CompletedProcess([], 0, "running\n")) as run, patch.object(settings.time, "sleep") as sleep:
            self.assertEqual(settings.network_ready(), {"ready": True})
        run.assert_called_once()
        sleep.assert_not_called()

    def test_network_ready_has_a_bounded_deadline(self):
        with patch.object(settings.subprocess, "run", return_value=settings.subprocess.CompletedProcess([], 0, "not running\n")) as run, patch.object(settings.time, "monotonic", side_effect=itertools.count(0, 0.1)), patch.object(settings.time, "sleep"):
            with self.assertRaisesRegex(RuntimeError, "did not become ready"):
                settings.network_ready(timeout=0.5)
        self.assertGreater(run.call_count, 0)
        self.assertLess(run.call_count, 5)
        self.assertTrue(all(0 < call.kwargs["timeout"] <= 0.5 for call in run.call_args_list))

    def setUp(self):
        self.monitor = dict(name="DP-1", description="Test display", width=1920, height=1200,
                            refreshRate=60.026, x=-1920, y=0, scale=1, transform=2,
                            mirrorOf="none", vrr=True, colorManagementPreset="srgb")

    def test_scale_reverts_when_panel_closes_or_shell_exits(self):
        with patch.object(settings, "monitors", return_value=[self.monitor]), patch.object(settings, "apply_scale") as apply, patch.object(settings.select, "select", return_value=([settings.sys.stdin], [], [])), patch.object(settings.sys, "stdin", io.StringIO("")), patch.object(settings, "emit"):
            settings.preview_scale("DP-1", 1.5)
        self.assertEqual([call.args[1] for call in apply.call_args_list], [1.5, 1])

    def test_scale_timeout_restores_original(self):
        with patch.object(settings, "monitors", return_value=[self.monitor]), patch.object(settings, "apply_scale") as apply, patch.object(settings.select, "select", return_value=([], [], [])), patch.object(settings, "emit"):
            settings.preview_scale("DP-1", 1.5)
        self.assertEqual([call.args[1] for call in apply.call_args_list], [1.5, 1])

    def test_scale_only_kept_after_compositor_accepts_it(self):
        for actual, expected in [(1.5, [1.5]), (1, [1.5, 1])]:
            with patch.object(settings, "monitors", side_effect=[[self.monitor], [{**self.monitor, "scale": actual}]]), patch.object(settings, "apply_scale") as apply, patch.object(settings.select, "select", return_value=([settings.sys.stdin], [], [])), patch.object(settings.sys, "stdin", io.StringIO("keep\n")), patch.object(settings, "emit"):
                settings.preview_scale("DP-1", 1.5)
            self.assertEqual([call.args[1] for call in apply.call_args_list], expected)

    def test_scale_preserves_layout_and_safely_quotes_monitor_name(self):
        monitor = {**self.monitor, "name": 'DP-1\"); os.execute("false") --'}
        with patch.object(settings, "command", return_value="ok") as command:
            settings.apply_scale(monitor, 1.5)
        args = command.call_args.args[0]
        self.assertEqual(args[:2], [settings.HYPRCTL, "eval"])
        self.assertNotIn("os.execute", args[2])
        self.assertIn("transform=2", args[2])
        self.assertIn(settings.lua_string("-1920x0"), args[2])
        self.assertIn(settings.lua_string("1920x1200@60.02600"), args[2])

    def test_invalid_and_too_small_scales_are_rejected(self):
        for scale in [float("nan"), float("inf"), 0, -1, 1.3, 4, 999]:
            self.assertFalse(settings.valid_scale(self.monitor, scale))
        self.assertTrue(settings.valid_scale(self.monitor, 1.5))

    def test_saved_scale_follows_display_description(self):
        with patch.object(settings, "monitors", return_value=[{**self.monitor, "name": "DP-3"}]), patch.object(settings, "apply_scale") as apply:
            settings.restore_scales({"Test display": 1.5, "Disconnected display": 2})
        self.assertEqual(apply.call_args.args[0]["name"], "DP-3")
        self.assertEqual(apply.call_args.args[1], 1.5)

    def test_dns_reapply_failure_restores_saved_profile(self):
        uuid = "683f4f74-035a-4be6-958c-5aeb678a6e93"
        previous = dict(zip(settings.DNS_FIELDS, ["no", "192.0.2.53", "no", ""]))
        calls = []
        def nm(*args):
            calls.append(args)
            if args == ("device", "reapply", "wlan0") and calls.count(args) == 1:
                raise RuntimeError("reapply rejected")
            return ""
        with patch.object(settings, "connection_info", return_value={"GENERAL.CON-UUID": [uuid]}), patch.object(settings, "profile_dns", return_value=previous), patch.object(settings, "nm", side_effect=nm):
            with self.assertRaisesRegex(RuntimeError, "previous settings restored"):
                settings.set_dns("wlan0", "cloudflare")
        changes = [call for call in calls if call[:2] == ("connection", "modify")]
        self.assertEqual(len(changes), 2)
        self.assertEqual(dict(zip(changes[-1][4::2], changes[-1][5::2])), previous)
        self.assertEqual(calls[-1], ("device", "reapply", "wlan0"))

    def test_dns_success_sets_both_protocols(self):
        uuid = "683f4f74-035a-4be6-958c-5aeb678a6e93"
        with patch.object(settings, "connection_info", return_value={"GENERAL.CON-UUID": [uuid]}), patch.object(settings, "profile_dns", return_value={}), patch.object(settings, "nm", return_value="") as nm:
            self.assertEqual(settings.set_dns("wlan0", "google"), {"ok": True})
        args = nm.call_args_list[0].args
        values = dict(zip(args[4::2], args[5::2]))
        self.assertEqual(values["ipv4.dns"], "8.8.8.8,8.8.4.4")
        self.assertEqual(values["ipv6.ignore-auto-dns"], "yes")
        self.assertEqual(nm.call_args.args, ("device", "reapply", "wlan0"))

    def test_fields_handle_ipv6_and_multiple_addresses(self):
        self.assertEqual(settings.fields("IP6.DNS[1]:2001:db8::53\nIP6.DNS[2]:2001:db8::54"), {"IP6.DNS": ["2001:db8::53", "2001:db8::54"]})
        with self.assertRaises(ValueError):
            settings.interface("../../etc")

    def test_battery_missing_optional_sysfs_attributes(self):
        with tempfile.TemporaryDirectory() as directory:
            battery = Path(directory) / "BAT0"
            battery.mkdir()
            for name, value in {"type": "Battery", "energy_full": "53380000", "energy_full_design": "57030000", "cycle_count": "121"}.items():
                (battery / name).write_text(value)
            result = settings.battery_info(Path(directory))
        self.assertEqual(result["capacity"], 53.4)
        self.assertEqual(result["health"], 94)
        self.assertNotIn("end", result)


unittest.main()
