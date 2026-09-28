pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import ".."

Singleton {
    id: root
    property bool brightnessBusy: false
    property int pendingBrightness: 0
    property int brightnessPercent: -1
    function refreshBrightness() {
        if (Config.preview)
            return;
        Runtime.run([Config.bin.brightnessctl, "-m", "info"], function (code, out) {
            var percent = parseInt(out.trim().split(",")[3]);
            if (!code && Number.isFinite(percent))
                root.brightnessPercent = percent;
        });
    }
    function brightness(delta) {
        if (Config.preview)
            return;
        pendingBrightness += delta;
        flushBrightness();
    }
    function flushBrightness() {
        if (brightnessBusy || !pendingBrightness)
            return;
        var delta = pendingBrightness;
        pendingBrightness = 0;
        brightnessBusy = true;
        Runtime.run([Config.bin.brightnessctl, "-m", "set", Math.abs(delta) + "%" + (delta > 0 ? "+" : "-")], function (
            code, out) {
            root.brightnessBusy = false;
            if (code)
                Runtime.report("Brightness could not be changed");
            else {
                var fields = out.trim().split(",");
                root.brightnessPercent = parseInt(fields[3] || "0");
                Runtime.showOsd("Brightness", root.brightnessPercent / 100);
            }
            root.flushBrightness();
        });
    }
    function applyNightlight(enabled, temperature) {
        if (Config.preview)
            return;
        var args = [Config.bin.hyprctl, "hyprsunset", enabled ? "temperature" : "identity"];
        if (enabled)
            args.push(String(temperature));
        Runtime.run(args, function (code) {
            if (code)
                Runtime.report("Night light is unavailable");
            else {
                Preferences.nightlight = enabled;
                Preferences.temperature = temperature;
            }
        });
    }
    function toggleNightlight() {
        applyNightlight(!Preferences.nightlight, Preferences.temperature);
    }
    function restoreNightlight() {
        if (Preferences.initialized && Preferences.nightlight)
            applyNightlight(true, Preferences.temperature);
    }
    function adjustNightlight(delta) {
        var next = Math.max(2500, Math.min(6000, (Preferences.nightlight ? Preferences.temperature : 6000)
                                           + delta));
        applyNightlight(next < 6000, next);
    }
    Connections {
        target: Preferences
        function onInitializedChanged() {
            root.restoreNightlight();
        }
    }
}
