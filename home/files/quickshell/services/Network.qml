pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    readonly property bool enabled: Networking.wifiEnabled
    readonly property bool hardwareEnabled: Networking.wifiHardwareEnabled
    readonly property var devices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var networks: devices.reduce((all, d) => all.concat(d.networks.values), [])
    readonly property var active: networks.find(n => n.connected) || null
    readonly property string deviceName: active?.device?.name || ""
    readonly property string networkName: active?.name || ""
    property var details: ({})
    property bool refreshing: false
    property bool changingDns: false
    readonly property var traffic: Metrics.networkDevices[deviceName] || ({})
    function toggle() {
        if (!Config.preview)
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }
    function refresh() {
        if (Config.preview || refreshing || changingDns || !deviceName || !Config.bin.settings)
            return;
        refreshing = true;
        var device = deviceName, name = networkName;
        Runtime.run([Config.bin.settings, "network-info", device], function(code, output) {
            root.refreshing = false;
            if (device === root.deviceName && name === root.networkName) {
                if (!code) root.details = Logic.parseJson(output, {});
                else root.details = {};
            }
        });
    }
    function setDns(preset) {
        if (Config.preview || changingDns || !deviceName)
            return;
        changingDns = true;
        Runtime.run([Config.bin.settings, "dns", deviceName, preset], function(code, output) {
            root.changingDns = false;
            if (code) Runtime.report(Logic.parseJson(output, {}).error || "DNS could not be changed");
            root.refresh();
        });
    }
    function advanced() {
        if (!Config.preview) {
            Runtime.launch([Config.bin.kitty, "-e", Config.bin.nmtui]);
            Runtime.closeMenu();
        }
    }
    onNetworkNameChanged: { details = {}; if (Runtime.menu === "wifi") refresh(); }
    onDeviceNameChanged: { details = {}; if (Runtime.menu === "wifi") refresh(); }
    Connections {
        target: Runtime
        function onMenuChanged() { if (Runtime.menu === "wifi") root.refresh(); }
    }
    Timer { interval: 5000; repeat: true; running: Runtime.menu === "wifi"; onTriggered: root.refresh() }
}
