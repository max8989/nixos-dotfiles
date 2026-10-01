#!@python@
"""Small, argument-only bridge for settings not exposed by Quickshell's APIs."""
import json
import math
import os
from pathlib import Path
import re
import select
import signal
import subprocess
import sys
import time

NMCLI = "@nmcli@"
HYPRCTL = "@hyprctl@"
DNS = {
    "auto": ("", ""),
    "cloudflare": ("1.1.1.1,1.0.0.1", "2606:4700:4700::1111,2606:4700:4700::1001"),
    "google": ("8.8.8.8,8.8.4.4", "2001:4860:4860::8888,2001:4860:4860::8844"),
}
DNS_FIELDS = ["ipv4.ignore-auto-dns", "ipv4.dns", "ipv6.ignore-auto-dns", "ipv6.dns"]


def command(args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=22, env={**os.environ, "LC_ALL": "C"})
    if result.returncode:
        raise RuntimeError("Settings command failed")
    return result.stdout.strip()


def nm(*args):
    return command([NMCLI, "--wait", "15", "--escape", "no", *args])


def network_ready(timeout=10):
    """Wait for the daemon, not connectivity (offline desktops must still start)."""
    deadline = time.monotonic() + timeout
    while (remaining := deadline - time.monotonic()) > 0:
        try:
            result = subprocess.run(
                [NMCLI, "-g", "RUNNING", "general"], text=True, capture_output=True,
                timeout=min(1, remaining), env={**os.environ, "LC_ALL": "C"},
            )
            if result.returncode == 0 and result.stdout.strip() == "running":
                return {"ready": True}
        except subprocess.TimeoutExpired:
            pass
        time.sleep(min(0.2, max(0, deadline - time.monotonic())))
    raise RuntimeError("NetworkManager did not become ready before desktop startup")


def fields(output):
    result = {}
    for line in output.splitlines():
        key, separator, value = line.partition(":")
        if separator:
            result.setdefault(re.sub(r"\[\d+\]$", "", key), []).append(value)
    return result


def interface(value):
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_.:-]{0,31}", value):
        raise ValueError("Invalid network interface")
    return value


def connection_info(device):
    return fields(nm("-t", "-f", "GENERAL.CON-UUID,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.DNS", "device", "show", interface(device)))


def profile_dns(uuid):
    data = fields(nm("-t", "-f", ",".join(DNS_FIELDS), "connection", "show", "uuid", uuid))
    return {key: data.get(key, [""])[0] for key in DNS_FIELDS}


def network_info(device):
    data = connection_info(device)
    uuid = data.get("GENERAL.CON-UUID", [""])[0]
    result = {"address": ", ".join(data.get("IP4.ADDRESS", [])), "gateway": ", ".join(data.get("IP4.GATEWAY", [])),
              "dns": ", ".join(data.get("IP4.DNS", []) + data.get("IP6.DNS", [])), "preset": "custom"}
    if uuid and uuid != "--":
        profile = profile_dns(uuid)
        for preset, (v4, v6) in DNS.items():
            def addresses(value):
                return {a for a in re.split(r"[,;\s]+", value) if a}
            if (addresses(profile["ipv4.dns"]) == addresses(v4) and addresses(profile["ipv6.dns"]) == addresses(v6)
                    and profile["ipv4.ignore-auto-dns"] == ("no" if preset == "auto" else "yes")
                    and profile["ipv6.ignore-auto-dns"] == ("no" if preset == "auto" else "yes")):
                result["preset"] = preset
    scan = nm("-t", "-f", "IN-USE,FREQ", "device", "wifi", "list", "ifname", device, "--rescan", "no")
    active = next((line[2:] for line in scan.splitlines() if line.startswith("*:")), "")
    match = re.search(r"\d+", active)
    if match:
        frequency = int(match[0])
        result["band"] = "6 GHz" if frequency >= 5925 else "5 GHz" if frequency >= 4900 else "2.4 GHz"
    return result


def set_dns(device, preset):
    if preset not in DNS:
        raise ValueError("Unknown DNS preset")
    info = connection_info(device)
    uuid = info.get("GENERAL.CON-UUID", [""])[0]
    if not re.fullmatch(r"[a-fA-F0-9-]{36}", uuid):
        raise RuntimeError("Connect to Wi-Fi before changing DNS")
    previous = profile_dns(uuid)
    v4, v6 = DNS[preset]
    enabled = "no" if preset == "auto" else "yes"
    values = dict(zip(DNS_FIELDS, [enabled, v4, enabled, v6]))

    def modify(settings):
        args = [part for pair in settings.items() for part in pair]
        nm("connection", "modify", "uuid", uuid, *args)

    modify(values)
    try:
        if connection_info(device).get("GENERAL.CON-UUID", [""])[0] != uuid:
            raise RuntimeError("The Wi-Fi connection changed")
        nm("device", "reapply", device)
    except (RuntimeError, subprocess.TimeoutExpired):
        modify(previous)
        # Only reapply if the same connection is still active.
        if connection_info(device).get("GENERAL.CON-UUID", [""])[0] == uuid:
            nm("device", "reapply", device)
        raise RuntimeError("DNS could not be applied; previous settings restored")
    return {"ok": True}


def battery_info(directory=Path("/sys/class/power_supply")):
    batteries = sorted(p for p in directory.iterdir() if (p / "type").read_text().strip() == "Battery")
    if not batteries:
        return {}
    battery = batteries[0]
    result = {}
    def read(name):
        try:
            return (battery / name).read_text().strip()
        except OSError:
            return None
    def number(name):
        value = read(name)
        return float(value) if value is not None else None
    result["model"] = read("model_name") or battery.name
    for name, key in [("cycle_count", "cycles"), ("charge_control_start_threshold", "start"), ("charge_control_end_threshold", "end")]:
        value = number(name)
        if value is not None and value >= 0:
            result[key] = int(value)
    full, design = number("energy_full"), number("energy_full_design")
    if full is not None:
        result["capacity"] = round(full / 1000000, 1)
    else:
        full, design = number("charge_full"), number("charge_full_design")
        voltage = number("voltage_min_design")
        if full is not None and voltage:
            result["capacity"] = round(full * voltage / 1e12, 1)
    if full is not None and design:
        result["health"] = round(full / design * 100)
    return result


def monitors():
    return json.loads(command([HYPRCTL, "-j", "monitors"]))


def lua_string(value):
    # Fixed-width byte escapes are valid Lua, including Unicode names, quotes,
    # newlines and backslashes. No shell is involved.
    return '"' + "".join("\\%03d" % byte for byte in str(value).encode()) + '"'


def valid_scale(monitor, scale):
    if not math.isfinite(scale) or not 1 <= scale <= 4:
        return False
    width, height = monitor["width"] / scale, monitor["height"] / scale
    return width >= 800 and height >= 500 and abs(width - round(width)) < .01 and abs(height - round(height)) < .01


def apply_scale(monitor, scale):
    # Retain the active mode, placement, rotation, mirror and colour settings.
    # Lua monitor rules merge with an existing connector-specific rule.
    options = {"output": monitor["name"], "scale": str(scale),
               "mode": f'{monitor["width"]}x{monitor["height"]}@{monitor["refreshRate"]:.5f}',
               "position": f'{monitor["x"]}x{monitor["y"]}', "transform": monitor.get("transform", 0),
               "mirror": "" if monitor.get("mirrorOf", "none") == "none" else monitor["mirrorOf"],
               "vrr": int(monitor.get("vrr", False)), "cm": monitor.get("colorManagementPreset", "srgb"),
               "sdrbrightness": monitor.get("sdrBrightness", 1), "sdrsaturation": monitor.get("sdrSaturation", 1)}
    source = "hl.monitor({" + ",".join(f"{key}={lua_string(value) if isinstance(value, str) else value}" for key, value in options.items()) + "})"
    result = command([HYPRCTL, "eval", source])
    if "error" in result.lower():
        raise RuntimeError("Display scale could not be applied")


def preview_scale(name, scale, timeout=15):
    original = next((m for m in monitors() if m["name"] == name), None)
    if original is None or not valid_scale(original, scale):
        raise ValueError("Unsupported scale for this display")
    changed = False
    def interrupted(_signal, _frame):
        raise RuntimeError("Display preview interrupted")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        changed = True
        apply_scale(original, scale)
        emit({"state": "preview", "seconds": timeout})
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        if ready and sys.stdin.readline().strip() == "keep":
            # Check the compositor accepted the scale before saving it.
            current = next((m for m in monitors() if m["name"] == name), None)
            if current and abs(current["scale"] - scale) < .01:
                changed = False
                emit({"state": "kept"})
                return
        emit({"state": "reverted"})
    finally:
        if changed:
            apply_scale(original, original["scale"])


def restore_scales(saved):
    for monitor in monitors():
        key = monitor.get("description") or monitor["name"]
        scale = saved.get(key)
        if isinstance(scale, (int, float)) and valid_scale(monitor, scale) and abs(monitor["scale"] - scale) > .01:
            apply_scale(monitor, scale)


def emit(value):
    print(json.dumps(value), flush=True)


def main():
    action, *args = sys.argv[1:]
    if action == "network-ready" and not args:
        emit(network_ready())
    elif action == "network-info" and len(args) == 1:
        emit(network_info(args[0]))
    elif action == "dns" and len(args) == 2:
        emit(set_dns(*args))
    elif action == "battery-info" and not args:
        emit(battery_info())
    elif action == "preview-scale" and len(args) == 2:
        preview_scale(args[0], float(args[1]))
    elif action == "restore-scales" and len(args) == 1:
        restore_scales(json.loads(args[0]))
    else:
        raise ValueError("Unknown settings action")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        emit({"error": str(error)})
        sys.exit(1)
