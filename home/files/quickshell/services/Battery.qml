pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    property int notificationId: 0
    readonly property var device: UPower.displayDevice
    readonly property bool present: !!device && device.isPresent && device.ready
    readonly property int percent: present ? Math.round(device.percentage * 100) : 0
    readonly property string band: Logic.batteryBand(percent, UPower.onBattery, present)
    property var alerts: ({})
    property var details: ({})
    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile
    readonly property string degradation: PowerProfiles.degradationReason === PerformanceDegradationReason.None ? ""
        : "Performance limited: " + PerformanceDegradationReason.toString(PowerProfiles.degradationReason)
    readonly property string summary: {
        if (!present)
            return "No battery detected · connected to AC power";
        var seconds = UPower.onBattery ? device.timeToEmpty : device.timeToFull;
        var remaining = seconds > 0 ? " · " + Math.floor(seconds / 3600) + " h " + Math.round((seconds % 3600) / 60) + " min " + (UPower.onBattery ? "remaining" : "until full") : "";
        return UPowerDeviceState.toString(device.state) + remaining;
    }
    function refreshDetails() {
        if (Config.preview || !Config.bin.settings)
            return;
        Runtime.run([Config.bin.settings, "battery-info"], function(code, output) {
            if (!code) root.details = Logic.parseJson(output, {});
        });
    }
    function setProfile(value) {
        if (!Config.preview)
            PowerProfiles.profile = value;
    }
    Connections {
        target: Runtime
        function onMenuChanged() { if (Runtime.menu === "battery") root.refreshDetails(); }
    }
    onBandChanged: {
        var next = Logic.batteryAlert(alerts, band);
        alerts = next.state;
        if (Config.preview || !present || !next.alert)
            return;
        Runtime.run([Config.bin.notifySend, "-a", "Battery", "-p", "-r", String(notificationId), "-u", band
                     === "full" ? "normal" : "critical", "Battery " + band + " (" + percent + "%)", band === "full"
                     ? "Battery charged." : "Connect the charger."], function (code, output) {
                         if (!code)
                             root.notificationId = parseInt(output.trim()) || 0;
                     });
    }
}
