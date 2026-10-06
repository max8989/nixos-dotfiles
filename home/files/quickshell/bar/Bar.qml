pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Networking
import ".."
import "../widgets"
import "../services"

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: !Preferences.barHidden && !Runtime.locked
    anchors {
        left: true
        right: true
        top: !Config.preview
        bottom: Config.preview
    }
    margins {
        left: Config.bar.sideMargin
        right: Config.bar.sideMargin
        top: Config.bar.margin
        bottom: Config.preview ? Config.bar.margin : 0
    }
    implicitHeight: Config.bar.height
    color: "transparent"
    WlrLayershell.namespace: "quickshell-bar"
    exclusionMode: Config.preview ? ExclusionMode.Ignore : ExclusionMode.Auto
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var connection: Networking.devices.values.find(d => d.connected)
    readonly property var wifi: connection?.networks.values.find(n => n.connected)
    readonly property string networkTip: (wifi ? wifi.name + " · " + Math.round(wifi.signalStrength * 100) + "%" : connection ? connection.name : "Disconnected") + (connection ? " · " + connection.address : "") + "\n" + Metrics.networkRate
    function open(name, item) {
        var point = item.mapToItem(root.contentItem, item.width / 2, 0);
        Runtime.toggleMenu(name, root.screen, point.x + Config.bar.sideMargin);
    }
    function menuSelected(name) {
        return Runtime.menu === name && Runtime.menuScreen === root.screen;
    }
    function workspace(id) {
        if (Config.preview)
            return;
        var existing = Hyprland.workspaces.values.find(w => w.id === id);
        if (existing)
            existing.activate();
        else
            Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + id + " })" : "workspace " + id);
    }
    function scrollWorkspace(direction) {
        if (Config.preview)
            return;
        var relative = direction > 0 ? "m-1" : "m+1";
        Hyprland.dispatch(Hyprland.usingLua ? 'hl.dsp.focus({ workspace = "' + relative + '" })' : "workspace " + relative);
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Connections {
        target: Runtime
        function onResumed() {
            clock.enabled = false;
            clock.enabled = true;
        }
    }
    IdleInhibitor {
        window: root
        enabled: Runtime.presentation && !Config.preview && !Runtime.locked
    }
    Glass {
        id: leftIsland
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: leftRow.implicitWidth + 12
        height: parent.height
        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 1
            Repeater {
                model: {
                    var list = Hyprland.workspaces.values.filter(w => w.id > 0 && (w.monitor === root.monitor || w.focused)).map(w => w.id);
                    if (list.indexOf(1) < 0)
                        list.push(1);
                    return list.sort((a, b) => a - b);
                }
                Chip {
                    required property int modelData
                    text: String(modelData)
                    highlighted: !!root.monitor && root.monitor.activeWorkspace?.id === modelData
                    tipTitle: "Workspace " + modelData
                    tip: "Click to switch · scroll to cycle"
                    onClicked: root.workspace(modelData)
                    onScrolled: direction => root.scrollWorkspace(direction)
                }
            }
            Text {
                text: Hyprland.activeToplevel?.title || "Hyprland"
                visible: root.width > 1500
                Layout.maximumWidth: Math.min(200, root.width * 0.13)
                color: Config.theme.dim
                font.family: Config.theme.uiFont
                font.pixelSize: 13
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }
    Glass {
        id: centerIsland
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        width: centerRow.implicitWidth + 12
        height: parent.height
        RowLayout {
            id: centerRow
            anchors.centerIn: parent
            spacing: 1
            Chip {
                text: Qt.formatDateTime(clock.date, root.width > 1700 ? "yyyy-MM-dd HH:mm" : "HH:mm")
                tipTitle: "Calendar"
                tip: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
                selected: root.menuSelected("calendar")
                onClicked: root.open("calendar", this)
            }
            Chip {
                text: "󰄲 " + Reminders.items.length
                tipTitle: "Reminders"
                tip: Reminders.items.slice(0, 8).join("\n") || "No open todos"
                selected: root.menuSelected("todos")
                onClicked: root.open("todos", this)
            }
            Chip {
                visible: Reminders.overdue.length > 0
                text: String(Reminders.overdue.length)
                foreground: Config.theme.urgent
                tipTitle: "Past due"
                tip: Reminders.overdue.slice(0, 8).map(t => t.text + "  · " + t.label).join("\n")
                onClicked: root.open("todos", this)
            }
        }
    }
    Glass {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: rightRow.implicitWidth + 12
        height: parent.height
        RowLayout {
            id: rightRow
            anchors.centerIn: parent
            spacing: 2
            Chip {
                visible: root.width > 1600
                text: " " + Math.round(Metrics.cpu) + "%"
                tipTitle: "Processor"
                tip: Math.round(Metrics.cpu) + "% in use" + (Metrics.temperature === null ? "" : " · " + Math.round(Metrics.temperature) + " °C") + "\nClick to open system monitor"
                onClicked: Runtime.launch([Config.bin.kitty, "-e", Config.bin.btop])
            }
            Chip {
                visible: root.width > 1800
                text: " " + Metrics.ram.percent + "%"
                tipTitle: "Memory"
                tip: (Metrics.ram.used / 1048576).toFixed(1) + " / " + (Metrics.ram.total / 1048576).toFixed(1) + " GiB in use\nClick to open system monitor"
                onClicked: Runtime.launch([Config.bin.kitty, "-e", Config.bin.btop])
            }
            Rectangle {
                visible: root.width > 1600
                implicitWidth: 1
                implicitHeight: 14
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Qt.alpha(Config.theme.text, 0.14)
            }
            Chip {
                text: root.wifi ? "󰤨" : root.connection ? "󰈀" : "󰤮"
                tipTitle: "Network"
                tip: root.networkTip
                selected: root.menuSelected("wifi")
                onClicked: root.open("wifi", this)
            }
            Chip {
                text: "󰂯"
                tipTitle: "Bluetooth"
                tip: "Manage connected devices"
                visible: root.width > 1350
                selected: root.menuSelected("bluetooth")
                onClicked: root.open("bluetooth", this)
            }
            Chip {
                text: Audio.sink?.audio?.muted ? "󰝟" : "󰕾"
                tipTitle: "Sound · " + (Audio.sink?.audio?.muted ? "Muted" : Math.round((Audio.sink?.audio?.volume || 0) * 100) + "%")
                tip: (Audio.sink?.description || "No output") + " · " + Math.round((Audio.sink?.audio?.volume || 0) * 100) + "%\nScroll for volume · right-click to mute"
                selected: root.menuSelected("audio")
                onClicked: root.open("audio", this)
                onRightClicked: Audio.mute(false)
                onScrolled: direction => Audio.change(false, direction * 5)
            }
            Chip {
                text: Audio.source?.audio?.muted ? "󰍭" : "󰍬"
                tipTitle: "Microphone · " + (Audio.source?.audio?.muted ? "Muted" : "On")
                tip: "Click to mute · scroll for input volume"
                visible: root.width > 1350
                onClicked: Audio.mute(true)
                onScrolled: direction => Audio.change(true, direction * 5)
            }
            Rectangle {
                visible: root.width > 1450
                implicitWidth: 1
                implicitHeight: 14
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                color: Qt.alpha(Config.theme.text, 0.14)
            }
            Chip {
                text: Preferences.nightlight ? "󰖔" : "󰖙"
                highlighted: Preferences.nightlight
                tipTitle: "Night light · " + (Preferences.nightlight ? "On" : "Off")
                tip: Preferences.temperature + " K · scroll to adjust\nClick for display settings · right-click for night light"
                visible: root.width > 1450
                selected: root.menuSelected("display")
                onClicked: root.open("display", this)
                onRightClicked: Display.toggleNightlight()
                onScrolled: direction => Display.adjustNightlight(direction * 500)
            }
            Chip {
                text: Runtime.presentation ? "󰅶" : "󰾪"
                highlighted: Runtime.presentation
                tipTitle: "Presentation mode · " + (Runtime.presentation ? "On" : "Off")
                tip: "Keep the screen awake while presenting"
                visible: root.width > 1450
                onClicked: Runtime.presentation = !Runtime.presentation
            }
            Chip {
                text: PowerProfiles.profile === PowerProfile.PowerSaver ? "󰾆" : PowerProfiles.profile === PowerProfile.Performance ? "󰓅" : "󰾅"
                tipTitle: "Power profile"
                tip: (PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced") + "\nClick to cycle"
                onClicked: Battery.setProfile(PowerProfiles.profile === PowerProfile.PowerSaver ? PowerProfile.Balanced
                    : PowerProfiles.profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver)
            }
            Chip {
                text: Battery.present ? (UPower.onBattery ? "󰁹 " : "󰂄 ") + Battery.percent + "%" : "AC"
                foreground: Battery.band === "critical" ? Config.theme.urgent : Battery.band === "low" ? Config.theme.warning : Config.theme.text
                tipTitle: "Battery · " + Battery.percent + "%"
                tip: Battery.summary + "\nClick for battery and power settings"
                selected: root.menuSelected("battery")
                onClicked: root.open("battery", this)
            }
            Loader {
                active: !Config.preview
                sourceComponent: trayComponent
            }
            Chip {
                text: Preferences.dnd ? "󰪑" : Notifications.entries.length ? "󰂚" : "󰂜"
                tipTitle: "Notifications" + (Preferences.dnd ? " · Do not disturb" : "")
                tip: Notifications.entries.length + " in history\nRight-click to toggle do not disturb"
                selected: root.menuSelected("notifications")
                onClicked: root.open("notifications", this)
                onRightClicked: Preferences.dnd = !Preferences.dnd
            }
            Chip {
                text: "⏻"
                tipTitle: "Power & controls"
                tip: "Lock, suspend and desktop settings"
                selected: root.menuSelected("power")
                onClicked: root.open("power", this)
            }
        }
    }
    Component {
        id: trayComponent
        RowLayout {
            spacing: 2
            Repeater {
                model: SystemTray.items
                Item {
                    id: trayItem
                    required property var modelData
                    property bool tipDismissed: false
                    implicitWidth: 28
                    implicitHeight: 30
                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: trayItem.modelData.icon
                    }
                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        radius: 10
                        color: trayMouse.containsMouse ? Qt.alpha(Config.theme.text, 0.08) : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                    }
                    HoverTip {
                        target: trayItem
                        title: trayItem.modelData.tooltipTitle || trayItem.modelData.title
                        text: trayItem.modelData.tooltipDescription || ""
                        active: trayMouse.containsMouse && !trayMouse.pressed && !trayItem.tipDismissed && !Runtime.menu && !Runtime.locked
                    }
                    MouseArea {
                        id: trayMouse
                        hoverEnabled: true
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onPressed: trayItem.tipDismissed = true
                        onExited: trayItem.tipDismissed = false
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton || trayItem.modelData.onlyMenu) {
                                var point = trayItem.mapToItem(root.contentItem, 0, trayItem.height);
                                trayItem.modelData.display(root, point.x, point.y);
                            } else if (mouse.button === Qt.MiddleButton)
                                trayItem.modelData.secondaryActivate();
                            else
                                trayItem.modelData.activate();
                        }
                        onWheel: function (wheel) {
                            trayItem.modelData.scroll(wheel.angleDelta.y, false);
                        }
                    }
                }
            }
        }
    }
}
