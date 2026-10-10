pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../widgets"
import "../services"

Scope {
    PanelWindow {
        visible: Config.features.osd && Runtime.osdVisible && !Runtime.locked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]

        anchors.bottom: true
        margins.bottom: 100
        implicitWidth: Runtime.osdProgress ? 300 : 380
        implicitHeight: osdContent.implicitHeight + 36
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-osd"
        Glass {
            anchors.fill: parent
            ColumnLayout {
                id: osdContent
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 18
                    rightMargin: 18
                }
                spacing: 12
                Text {
                    Layout.fillWidth: true
                    text: Runtime.osdLabel + (Runtime.osdProgress ? "  " + Math.round(Runtime.osdValue * 100) + "%" : "")
                    color: Config.theme.text
                    font.family: Config.theme.uiFont
                    font.pixelSize: Config.fonts.body
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                }
                Rectangle {
                    visible: Runtime.osdProgress
                    Layout.fillWidth: true
                    implicitHeight: 5
                    radius: 3
                    color: Config.theme.surface
                    Rectangle {
                        width: parent.width * Math.min(1, Runtime.osdValue)
                        height: parent.height
                        radius: 3
                        color: Config.theme.accent
                    }
                }
            }
        }
    }
    PanelWindow {
        visible: Notifications.popups.length > 0 && !Runtime.locked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]

        anchors {
            top: true
            right: true
        }
        margins {
            top: Config.bar.height + 18
            right: 18
        }
        implicitWidth: 390
        implicitHeight: cards.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-notifications"
        Column {
            id: cards
            width: parent.width
            spacing: 8
            Repeater {
                model: Notifications.popups.slice(0, 3)
                NotificationCard {
                    required property var modelData
                    width: cards.width
                    entry: modelData
                }
            }
        }
    }
}
