pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    property bool brightnessBusy: false
    property int pendingBrightness: 0
    property int brightnessPercent: -1
    property int requestedBrightness: -1
    readonly property var monitors: Hyprland.monitors.values
    property string pendingMonitor: ""
    property string pendingMonitorKey: ""
    property real pendingScale: 1
    property int scaleSeconds: 0
    readonly property bool scaleBusy: scaleProcess.running
    property bool restoringScales: false
    function setBrightness(percent) {
        if (Config.preview)
            return;
        requestedBrightness = Math.max(1, Math.min(100, Math.round(percent)));
        brightnessDelay.restart();
    }
    Timer { id: brightnessDelay; interval: 70; onTriggered: root.flushBrightness() }
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
        if (brightnessBusy || (!pendingBrightness && requestedBrightness < 0))
            return;
        var delta = pendingBrightness;
        var target = requestedBrightness;
        pendingBrightness = 0;
        requestedBrightness = -1;
        brightnessBusy = true;
        Runtime.run([Config.bin.brightnessctl, "-m", "set", target >= 0 ? Math.max(1, Math.min(100, target + delta)) + "%" : Math.abs(delta) + "%" + (delta > 0 ? "+" : "-")], function (
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
    function scalesFor(monitor) {
        if (!monitor)
            return [];
        return [1, 1.25, 1.5, 1.6, 2, 2.5, 3, 4].filter(scale => {
            var w = monitor.width / scale, h = monitor.height / scale;
            return w >= 800 && h >= 500 && Math.abs(w - Math.round(w)) < 0.01 && Math.abs(h - Math.round(h)) < 0.01;
        });
    }
    function previewScale(monitor, scale) {
        if (Config.preview || scaleBusy || restoringScales || !monitor || !Config.bin.settings)
            return;
        pendingMonitor = monitor.name;
        pendingMonitorKey = monitor.description || monitor.name;
        pendingScale = scale;
        scaleProcess.command = [Config.bin.settings, "preview-scale", monitor.name, String(scale)];
        scaleProcess.running = true;
    }
    function keepScale() { if (scaleBusy && scaleSeconds > 0) scaleProcess.write("keep\n"); }
    function revertScale() { if (scaleBusy) scaleProcess.write("revert\n"); }
    function restoreScales() {
        if (Config.preview || !Preferences.initialized || !Object.keys(Preferences.monitorScales).length || scaleBusy || restoringScales || !Config.bin.settings)
            return;
        restoringScales = true;
        Runtime.run([Config.bin.settings, "restore-scales", JSON.stringify(Preferences.monitorScales)], function(code) {
            root.restoringScales = false;
            if (code) Runtime.report("Saved display scale could not be restored");
        });
    }
    Process {
        id: scaleProcess
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                var event = Logic.parseJson(data, {});
                if (event.state === "preview") root.scaleSeconds = event.seconds;
                else if (event.state === "kept") {
                    var saved = Object.assign({}, Preferences.monitorScales);
                    saved[root.pendingMonitorKey] = root.pendingScale;
                    Preferences.monitorScales = saved;
                    root.scaleSeconds = 0;
                } else if (event.error) Runtime.report(event.error);
            }
        }
        onExited: code => {
            root.scaleSeconds = 0;
            root.pendingMonitor = "";
            Hyprland.refreshMonitors();
            if (code) Runtime.report("Display scale failed; the previous scale was restored where possible");
        }
    }
    Timer { interval: 1000; repeat: true; running: root.scaleSeconds > 0; onTriggered: root.scaleSeconds-- }
    Timer { id: restoreDelay; interval: 600; onTriggered: root.restoreScales() }
    onMonitorsChanged: restoreDelay.restart()
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" || event.name === "monitoradded") restoreDelay.restart();
        }
    }
    Connections {
        target: Runtime
        function onMenuChanged() { if (Runtime.menu !== "display") root.revertScale(); }
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
            restoreDelay.restart();
        }
    }
    Component.onCompleted: restoreDelay.restart()
}
