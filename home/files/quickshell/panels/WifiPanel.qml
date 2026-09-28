pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import ".."
import "../services" as Services
import "../widgets"
import "../Logic.js" as Logic

SettingsScroll {
    id: root
    property var network: Services.Network
    signal connectRequested(var network)
    function focusDefault() { radio.forceActiveFocus(Qt.TabFocusReason); }
    function networks(known) {
        return network.networks.filter(n => !!n.known === known).sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name));
    }
    function traffic(value) { return value === undefined ? "—" : Logic.bytes(value); }
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            SettingsText { text: root.network.active?.name || (root.network.enabled ? "Not connected" : "Wi-Fi off"); Layout.fillWidth: true }
            SettingsText { text: root.network.active ? Math.round(root.network.active.signalStrength * 100) + "% signal" + (root.network.details.band ? " · " + root.network.details.band : "") : "Select a network below"; caption: true }
        }
        SettingsButton {
            id: radio
            objectName: "wifiRadio"
            text: root.network.enabled ? "Turn off" : "Turn on"
            enabled: root.network.hardwareEnabled && !root.network.changingDns
            selected: root.network.enabled
            onClicked: root.network.toggle()
        }
    }
    SettingsText {
        visible: !root.network.hardwareEnabled
        text: "Wi-Fi is blocked by the hardware switch or airplane mode."
        Layout.fillWidth: true
        color: Config.theme.warning
    }
    GridLayout {
        visible: !!root.network.active
        Layout.fillWidth: true
        columns: 2
        uniformCellWidths: true
        columnSpacing: 20
        rowSpacing: 8
        Repeater {
            model: [
                ["Receiving", root.traffic(root.network.traffic.receiving) + "/s"],
                ["Sending", root.traffic(root.network.traffic.sending) + "/s"],
                ["Downloaded since boot", root.traffic(root.network.traffic.rx)],
                ["Uploaded since boot", root.traffic(root.network.traffic.tx)],
                ["IP address", root.network.details.address || "—"],
                ["Gateway", root.network.details.gateway || "—"]
            ]
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                SettingsText { text: modelData[0]; caption: true }
                SettingsText { text: modelData[1]; Layout.fillWidth: true }
            }
        }
    }
    ColumnLayout {
        visible: !!root.network.active
        Layout.fillWidth: true
        spacing: 8
        SettingsText { text: "DNS PROVIDER"; caption: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [{id: "auto", label: "DHCP"}, {id: "cloudflare", label: "Cloudflare"}, {id: "google", label: "Google"}]
                SettingsButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    selected: root.network.details.preset === modelData.id
                    enabled: !root.network.changingDns && root.network.details.preset !== undefined
                    onClicked: root.network.setDns(modelData.id)
                }
            }
        }
        SettingsText {
            text: root.network.changingDns ? "Applying DNS…" : root.network.details.dns || "Loading DNS settings…"
            caption: true
            Layout.fillWidth: true
        }
        SettingsText { text: "Saved for this Wi-Fi connection. Custom DNS is available in advanced settings."; caption: true; Layout.fillWidth: true }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Config.theme.border }
    Repeater {
        model: [true, false]
        ColumnLayout {
            id: group
            required property bool modelData
            Layout.fillWidth: true
            spacing: 7
            SettingsText { text: group.modelData ? "KNOWN NETWORKS" : "OTHER NETWORKS"; caption: true }
            Repeater {
                model: root.networks(group.modelData)
                SettingsButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: (modelData.connected ? "✓  " : "") + modelData.name
                    detail: (modelData.stateChanging ? "Connecting…" : modelData.connected ? "Connected · select to disconnect" : modelData.security === WifiSecurityType.Open ? "Open network" : "Secured") + " · " + Math.round(modelData.signalStrength * 100) + "%"
                    selected: modelData.connected
                    enabled: root.network.enabled && !modelData.stateChanging && !root.network.changingDns
                    onClicked: root.connectRequested(modelData)
                }
            }
            SettingsText { visible: root.networks(group.modelData).length === 0; text: group.modelData ? "No saved networks in range" : root.network.enabled ? "Scanning for networks…" : "Wi-Fi is off"; caption: true }
        }
    }
    SettingsButton {
        Layout.fillWidth: true
        text: "Advanced network settings"
        detail: "Hidden networks, custom DNS and connection profiles"
        onClicked: root.network.advanced()
    }
}
