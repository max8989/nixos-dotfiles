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
