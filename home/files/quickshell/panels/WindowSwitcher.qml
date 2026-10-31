pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../widgets"
import "WindowHistory.js" as History

PanelWindow {
    id: root
    property var entries: []
    property int selectedIndex: -1
    property bool opened: false
    property bool loading: false
    property bool acceptPending: false
    property int pendingSteps: 0
    property int requestSerial: 0
    visible: opened && !Runtime.locked
    readonly property var targetScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]
    readonly property int tileSize: 144
    readonly property int tileStride: tileSize + 12
    readonly property int columns: Math.max(1, Math.min(5, entries.length, Math.floor(((targetScreen?.width || 800) - 88) / tileStride)))
    readonly property int rows: Math.max(1, Math.min(2, Math.ceil(entries.length / columns), Math.floor(((targetScreen?.height || 600) - 200) / tileStride)))
    readonly property var applicationModel: DesktopEntries.applications
    screen: targetScreen
    implicitWidth: columns * tileStride + 40
    implicitHeight: Math.min(content.implicitHeight + 40, (targetScreen?.height || 600) - 80)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-switcher"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function step(delta) {
        if (!Config.valid || Config.preview || Runtime.locked)
            return;
        if (opened) {
            selectedIndex = History.advance(selectedIndex, delta, entries.length);
            return;
        }
        if (loading) {
            pendingSteps += delta;
            return;
        }
        Runtime.closeMenu();
        loading = true;
        acceptPending = false;
        pendingSteps = delta;
        var serial = ++requestSerial;
        Runtime.run([Config.bin.hyprctl, "-j", "clients"], function (code, out) {
            if (serial !== root.requestSerial || Runtime.locked)
                return;
            root.loading = false;
            var clients;
            try {
                clients = JSON.parse(out);
            } catch (_) {
                clients = null;
            }
            root.entries = History.snapshot(clients);
            if (code || !clients) {
                root.cancel();
                Runtime.report("Could not read window history");
                return;
            }
            if (!root.entries.length) {
                root.cancel();
                return;
            }
            root.selectedIndex = History.advance(0, root.pendingSteps, root.entries.length);
            if (root.acceptPending)
                root.accept();
            else
                root.opened = true;
        });
    }
    function cancel() {
        ++requestSerial;
        opened = false;
        loading = false;
        acceptPending = false;
        entries = [];
        selectedIndex = -1;
    }
    function accept() {
        if (loading) {
            acceptPending = true;
            return;
        }
        var selected = entries[selectedIndex];
        cancel();
        if (!selected || Config.preview || Runtime.locked)
            return;
        Runtime.run([Config.bin.hyprctl, "dispatch", 'hl.dsp.focus({window = "address:' + selected.address + '"})'], function (code) {
            if (code)
                Runtime.report("The selected window is no longer available");
        });
    }
    onVisibleChanged: if (visible)
        keyboard.forceActiveFocus()
    Connections {
        target: Runtime
        function onLockedChanged() {
            if (Runtime.locked)
                root.cancel();
        }
    }
    IpcHandler {
        target: "switcher"
        function next(): void {
            root.step(1);
        }
        function previous(): void {
            root.step(-1);
        }
        function accept(): void {
            root.accept();
        }
        function cancel(): void {
            root.cancel();
        }
        function state(): string {
            return JSON.stringify({
                open: root.opened,
                loading: root.loading,
                selected: root.selectedIndex,
                windows: root.entries
            });
        }
    }
    Glass {
        anchors.fill: parent
    }
    FocusScope {
        id: keyboard
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                root.cancel();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.accept();
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                root.step(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
            else if (event.key === Qt.Key_Right)
                root.step(1);
            else if (event.key === Qt.Key_Left)
                root.step(-1);
            else if (event.key === Qt.Key_Down)
                root.step(root.columns);
            else if (event.key === Qt.Key_Up)
                root.step(-root.columns);
            else
                return;
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt && !event.isAutoRepeat) {
                root.accept();
                event.accepted = true;
            }
        }
        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Recent windows"
                    color: Config.theme.text
                    font.family: Config.theme.uiFont
                    font.pixelSize: Config.fonts.heading
                    font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: (root.selectedIndex + 1) + " / " + root.entries.length
                    color: Config.theme.dim
                    font.pixelSize: Config.fonts.body
                }
            }
            GridView {
                id: windows
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.rows * root.tileStride
                clip: true
                cellWidth: root.tileStride
                cellHeight: root.tileStride
                model: root.entries
                currentIndex: root.selectedIndex
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.selectedIndex
                    readonly property var desktopEntry: root.applicationModel.values.length ? DesktopEntries.heuristicLookup(modelData.app) : null
                    width: root.tileSize
                    height: root.tileSize
                    radius: Config.theme.radius
                    color: Qt.alpha(Config.theme.accent, selected ? 0.2 : tileMouse.containsMouse ? 0.1 : 0.04)
                    border.width: selected ? 2 : 0
                    border.color: Config.theme.accent
                    Accessible.name: modelData.title + ", " + modelData.app
                    Accessible.role: Accessible.ListItem
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6
                        Image {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            source: Quickshell.iconPath(row.desktopEntry?.icon || row.modelData.app, true) || Quickshell.iconPath("application-x-executable", true)
                            sourceSize.width: 104
                            sourceSize.height: 104
                            fillMode: Image.PreserveAspectFit
                            Text {
                                anchors.centerIn: parent
                                visible: parent.status === Image.Error || parent.status === Image.Null
                                text: row.modelData.app.slice(0, 1).toUpperCase()
                                color: Config.theme.accent
                                font.pixelSize: 32
                                font.bold: true
                            }
                        }
                        Text {
                            text: row.desktopEntry?.name || row.modelData.app
                            color: Config.theme.text
                            font.family: Config.theme.uiFont
                            font.pixelSize: Config.fonts.subtitle
                            font.bold: row.selected
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: row.modelData.title
                            color: Config.theme.dim
                            font.pixelSize: Config.fonts.body
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedIndex = row.index;
                            root.accept();
                        }
                    }
                }
            }
            Text {
                text: root.entries[root.selectedIndex]?.title || ""
                color: Config.theme.text
                font.pixelSize: Config.fonts.body
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: "Tab / Shift+Tab to cycle · Release Alt to switch · Esc to cancel"
                color: Config.theme.dim
                font.pixelSize: Config.fonts.body
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
