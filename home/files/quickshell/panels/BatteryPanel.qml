pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import ".."
import "../services"
import "../widgets"

SettingsScroll {
    id: root
    property var battery: Battery
    function focusDefault() { balanced.forceActiveFocus(Qt.TabFocusReason); }
    RowLayout {
        Layout.fillWidth: true
        SettingsText { text: root.battery.details.model || "Laptop battery"; Layout.fillWidth: true }
        SettingsText { text: root.battery.present ? root.battery.percent + "%" : "AC"; font.pixelSize: 38; color: Config.theme.accent }
    }
    Rectangle {
        Layout.fillWidth: true
        height: 9
        radius: 5
        color: Config.theme.surface
        Rectangle { width: parent.width * root.battery.percent / 100; height: 9; radius: 5; color: Config.theme.accent }
    }
    SettingsText { text: root.battery.summary; Layout.fillWidth: true }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        uniformCellWidths: true
        columnSpacing: 24
        rowSpacing: 12
        Repeater {
            model: [
                ["Full capacity", root.battery.details.capacity === undefined ? "Unavailable" : root.battery.details.capacity + " Wh"],
                ["Battery health", root.battery.details.health === undefined ? "Unavailable" : root.battery.details.health + "%"],
                ["Charge cycles", root.battery.details.cycles === undefined ? "Unavailable" : String(root.battery.details.cycles)],
                ["Charge limit", root.battery.details.end === undefined ? "Unavailable" : (root.battery.details.start > 0 ? root.battery.details.start + "–" : "") + root.battery.details.end + "%"]
            ]
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 4
                SettingsText { text: modelData[0]; caption: true }
                SettingsText { text: modelData[1] }
            }
        }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Config.theme.border }
    SettingsText { text: "POWER PROFILE"; caption: true }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        SettingsButton {
            text: "Saver"
            Layout.fillWidth: true
            selected: root.battery.profile === PowerProfile.PowerSaver
            onClicked: root.battery.setProfile(PowerProfile.PowerSaver)
        }
        SettingsButton {
            id: balanced
            objectName: "balancedProfile"
            text: "Balanced"
            Layout.fillWidth: true
            selected: root.battery.profile === PowerProfile.Balanced
            onClicked: root.battery.setProfile(PowerProfile.Balanced)
        }
        SettingsButton {
            text: "Performance"
            Layout.fillWidth: true
            enabled: root.battery.hasPerformanceProfile
            selected: root.battery.profile === PowerProfile.Performance
            onClicked: root.battery.setProfile(PowerProfile.Performance)
        }
    }
    SettingsText {
        Layout.fillWidth: true
        text: "Power saver extends battery life. Performance favours speed over battery life."
        caption: true
    }
    SettingsText {
        visible: root.battery.degradation !== ""
        Layout.fillWidth: true
        text: root.battery.degradation
        color: Config.theme.warning
    }
    SettingsButton {
        Layout.fillWidth: true
        text: Runtime.presentation ? "Keep awake · on" : "Keep awake · off"
        detail: "Prevent automatic screen blanking and sleep"
        selected: Runtime.presentation
        onClicked: Runtime.presentation = !Runtime.presentation
    }
}
