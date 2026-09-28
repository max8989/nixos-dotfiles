pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."
import "../widgets"
import "../services"
import "../Logic.js" as Logic

PanelWindow {
    id: root
    signal powerRequested(string action)
    visible: Runtime.menu !== "" && !Runtime.locked && Config.features.menus
    screen: Runtime.menuScreen || Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
            || Quickshell.screens[0]
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-menu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    readonly property bool fromBar: Runtime.menuAnchorX >= 0
    color: fromBar ? "transparent" : "#44000000"
    property var rows: []
    property var filtered: Logic.search(rows, search.text)
    property string passwordPrompt: ""
    property var pendingWifi: null
    property string confirmation: ""
    property string folderPath: Config.paths.home || "/"
    Component.onCompleted: if (Preferences.initialized && Preferences.folder)
                               folderPath = Preferences.folder
    property int requestSerial: 0
    property bool clipboardBusy: false
    readonly property var wifiNetworks: Networking.devices.values.reduce((all, d) => all.concat(
                                                                                         d.networks.values),
    [])
    readonly property var bluetoothDevices: Bluetooth.devices.values
    readonly property string heading: ({
                                           apps: "Applications",
                                           clipboard: "Clipboard",
                                           files: "Files",
                                           vim: "Vim reference",
                                           lazyvim: "LazyVim reference",
                                           todos: "Reminders",
                                           audio: "Audio devices",
                                           wifi: "Wi-Fi",
                                           bluetooth: "Bluetooth",
                                           power: "Power",
                                           powerProfiles: "Power profile",
                                           notifications: "Notifications",
                                           calendar: "Calendar",
                                           status: "System status"
                                       })[Runtime.menu] || "Desktop"
    function row(title, action, subtitle, icon) {
        return {
            title: title,
            action: action,
            subtitle: subtitle || "",
            icon: icon || ""
        };
    }
    function refresh() {
        var menu = Runtime.menu;
        var items = [];
        if (menu === "apps") {
            items = DesktopEntries.applications.values.filter(a => !a.noDisplay).map(a => row(a.name, () => {
                if (!Config.preview)
                    a.execute();
                Runtime.closeMenu();
            }, a.genericName || a.comment, a.icon));
            items.sort((a, b) => a.title.localeCompare(b.title));
        } else if (menu === "clipboard") {
            var serial = ++requestSerial;
            rows = [];
            Runtime.run([Config.bin.cliphist, "list"], function (code, out) {
                if (serial !== root.requestSerial || Runtime.menu !== "clipboard")
                    return;
                root.rows = Logic.clipboardEntries(out).map(entry => {
                    return root.row(entry.title, () => root.restoreClipboard(entry.id),
                                    entry.image ? "Image · select to copy" : "Text · select to copy");
                });
                if (code)
                    Runtime.report("Clipboard history could not be loaded");
            });
            return;
        } else if (menu === "files") {
            items.push(row("↑ Parent directory", () => navigate(folderPath.replace(/\/?[^/]+\/?$/, "") || "/"),
            folderPath));
            items.push(row("Open this folder", () => {
                Runtime.launch([Config.bin.xdgOpen, folderPath]);
                Runtime.closeMenu();
            }));
            for (var i = 0; i < folders.count; i++) {
                var name = folders.get(i, "fileName"), directory = folders.get(i, "fileIsDir"), path
                                                                                                = folders.get(
                                                                                                    i, "filePath");
                items.push(fileRow(name, path, directory));
            }
        } else if (menu === "vim" || menu === "lazyvim") {
            items = reference.text().split("\n").filter(Boolean).map(line => row(line, () => {},
            "Reference"));

        } else if (menu === "todos") {
            items = Reminders.items.map(task => row(task, () => {
                Reminders.openNote(Config.paths.todoNote);
                Runtime.closeMenu();
            }));
            items.push(row("Open TODO note", () => Reminders.openNote(Config.paths.todoNote)));
            items.push(row("Open vault Home", () => Reminders.openNote(Config.paths.homeNote)));
            items.push(row("Refresh", () => Reminders.refresh()));
        } else if (menu === "audio") {
            items = Audio.sinks.map(n => row((n === Audio.sink ? "✓ " : "") + n.description, ()
                                             => Audio.select(n), "Output"));
            items = items.concat(Audio.sources.map(n => row((n === Audio.source ? "✓ " : "") + n.description, (
                                                                ) => Audio.select(n), "Input")));
            items.push(row("Toggle output mute", () => Audio.mute(false)));
            items.push(row("Toggle microphone mute", () => Audio.mute(true)));
        } else if (menu === "wifi") {
            items.push(row(Networking.wifiEnabled ? "Turn Wi-Fi off" : "Turn Wi-Fi on", () => {
                if (!Config.preview)
                    Networking.wifiEnabled = !Networking.wifiEnabled;
            }));
            items = items.concat(wifiNetworks.slice().sort((a, b) => (b.signalStrength || 0) - (
                                     a.signalStrength || 0)).map(n => row((n.connected ? "✓ " : "") + n.name, (
                                                                              ) => connectNetwork(n), (
                                                                                  n.connected
                                                                                  ? "Connected · click to disconnect" :
                                                                                    n.known ? "Saved" :
                                                                                              "Available") + (
                                                                                  n.signalStrength
                                                                                  === undefined ? "" : " · "
                                                                                                  + Math.round(
                                                                                                      n.signalStrength
                                                                                                      * 100) + "%"))));
            items.push(row("Hidden networks / advanced settings", () => {
                Runtime.launch([Config.bin.kitty, "-e", Config.bin.nmtui]);
                Runtime.closeMenu();
            }));
        } else if (menu === "bluetooth") {
            items = Bluetooth.adapters.values.map(a => row(a.enabled ? "Turn Bluetooth off" : "Turn Bluetooth on", (
                                                               ) => {
                                                                   if (!Config.preview)
                                                                       a.enabled = !a.enabled;
                                                               }, a.name));
            items = items.concat(bluetoothDevices.map(d => row((d.connected ? "✓ " : "") + d.name, () => {
                if (!Config.preview)
                    d.connected = !d.connected;
            }, d.paired ? "Paired" : "Pair in Bluetooth settings")));
            items.push(row("Pair / manage devices", () => {
                Runtime.launch([Config.bin.bluetooth]);
                Runtime.closeMenu();
            }));
        } else if (menu === "powerProfiles") {
            items = [row("Power saver", () => setProfile(PowerProfile.PowerSaver)), row("Balanced", () => setProfile(
                                                                                                              PowerProfile.Balanced))];
            if (PowerProfiles.hasPerformanceProfile)
                items.push(row("Performance", () => setProfile(PowerProfile.Performance)));
        } else if (menu === "power") {
            items = ["Lock", "Suspend", "Hibernate", "Logout", "Reboot", "Shutdown"].map(action => row(action,
                                                                                                       () => {
                                                                                                           if (Config.preview) {
                                                                                                               Runtime.report(
                                                                                                                           "Power actions are disabled in preview");
                                                                                                               return;
                                                                                                           }
                                                                                                           if (action
                                                                                                                   === "Lock"
                                                                                                                   || action
                                                                                                                   === "Suspend") {
                                                                                                               root.powerRequested(
                                                                                                                           action.toLowerCase(
                                                                                                                               ));
                                                                                                               Runtime.closeMenu(
                                                                                                                           );
                                                                                                           } else
                                                                                                               root.confirmation
                                                                                                                       = action.toLowerCase(
                                                                                                                           );
                                                                                                       }));
            items.push(row("Night light: " + (Preferences.nightlight ? "on" : "off"), ()
                           => Display.toggleNightlight()));
            items.push(row("Presentation mode: " + (Runtime.presentation ? "on" : "off"), () => {
                Runtime.presentation = !Runtime.presentation;
                root.refresh();
            }));
            items.push(row("System status", () => Runtime.menu = "status"));
        } else if (menu === "status") {
            items = [row("CPU " + Math.round(Metrics.cpu) + "%", () => Runtime.launch([Config.bin.kitty, "-e",
                                                                                       Config.bin.btop]),
            Metrics.temperature === null ? "Temperature unavailable" : Math.round(Metrics.temperature)
                                           + " °C"), row("Memory " + Metrics.ram.percent + "%", () => Runtime.launch(
                                                                                                          [Config.bin.kitty,
                                                                                                           "-e", Config.bin.btop]),
                                           (Metrics.ram.used / 1048576).toFixed(1) + " / " + (Metrics.ram.total
                                                                                              / 1048576).toFixed(
                                               1) + " GiB"), row("Battery " + (Battery.present
                                                                               ? Battery.percent + "%" : "AC"),
                                                                 () => {}, Battery.band), row("Network", ()
                                                                                              => Runtime.menu
                                                                                                 = "wifi", Metrics.networkRate),
                     row("Bluetooth", () => Runtime.menu = "bluetooth"), row("Audio and microphone", ()
                                                                             => Runtime.menu = "audio"), row(
                         "Night light", () => Display.toggleNightlight(), Preferences.nightlight
                         ? Preferences.temperature + " K" : "Off")];
        }
        rows = items;
    }
    function navigate(path) {
        folderPath = path;
        Preferences.folder = path;
    }
    function fileRow(name, path, directory) {
        return row((directory ? "▸ " : "") + name, () => {
            if (directory)
                navigate(path);
            else {
                Runtime.launch([Config.bin.xdgOpen, path]);
                Runtime.closeMenu();
            }
        }, directory ? "Folder" : "File");
    }
    function connectNetwork(network) {
        if (Config.preview)
            return;
        if (network.connected) {
            network.disconnect();
            return;
        }
        pendingWifi = network;
        network.connect();
    }
    function setProfile(profile) {
        if (!Config.preview)
            PowerProfiles.profile = profile;
        Runtime.closeMenu();
    }
    function activate() {
        var item = filtered[list.currentIndex];
        if (item)
            item.action();
    }
    function restoreClipboard(id) {
        if (Config.preview || clipboardBusy)
            return;
        clipboardBusy = true;
        var serial = requestSerial;
        Runtime.run([Config.bin.clipboard, id], function (code) {
            root.clipboardBusy = false;
            if (serial !== root.requestSerial || Runtime.menu !== "clipboard")
                return;
            if (code) {
                Runtime.report("Could not copy this entry. It may have been removed from history.");
                root.refresh();
            } else {
                Runtime.closeMenu();
            }
        });
    }
    onFilteredChanged: list.currentIndex = 0
    onWifiNetworksChanged: if (Runtime.menu === "wifi")
                               refresh()
    onBluetoothDevicesChanged: if (Runtime.menu === "bluetooth")
                                   refresh()
    onFolderPathChanged: search.text = ""
    onVisibleChanged: if (visible) {
                          reveal.restart();
                          search.text = "";
                          confirmation = "";
                          passwordPrompt = "";
                          pendingWifi = null;
                          refresh();
                          focusTimer.restart();
                      }
    Connections {
        target: Runtime
        function onMenuChanged() {
            root.requestSerial++;
            root.passwordPrompt = "";
            root.pendingWifi = null;
            root.confirmation = "";
            password.text = "";
            search.text = "";
            root.refresh();
            focusTimer.restart();
        }
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            if (Runtime.menu === "apps")
                root.refresh();
        }
    }
    Connections {
        target: Reminders
        function onItemsChanged() {
            if (Runtime.menu === "todos")
                root.refresh();
        }
    }
    Connections {
        target: Audio
        function onSinkChanged() {
            if (Runtime.menu === "audio")
                root.refresh();
        }
        function onSinksChanged() {
            if (Runtime.menu === "audio")
                root.refresh();
        }
        function onSourceChanged() {
            if (Runtime.menu === "audio")
                root.refresh();
        }
        function onSourcesChanged() {
            if (Runtime.menu === "audio")
                root.refresh();
        }
    }
    Connections {
        target: Preferences
        function onInitializedChanged() {
            if (Preferences.folder)
                root.folderPath = Preferences.folder;
        }
        function onNightlightChanged() {
            if (Runtime.menu === "power" || Runtime.menu === "status")
                root.refresh();
        }
    }
    Instantiator {
        model: root.wifiNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (Runtime.menu === "wifi")
                    root.refresh();
            }
            function onSignalStrengthChanged() {
                if (Runtime.menu === "wifi")
                    root.refresh();
            }
        }
    }
    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() {
                if (Runtime.menu === "bluetooth")
                    root.refresh();
            }
            function onPairedChanged() {
                if (Runtime.menu === "bluetooth")
                    root.refresh();
            }
        }
    }
    Instantiator {
        model: Bluetooth.adapters
        delegate: Connections {
            required property var modelData
            target: modelData
            function onEnabledChanged() {
                if (Runtime.menu === "bluetooth")
                    root.refresh();
            }
        }
    }
    Connections {
        target: root.pendingWifi
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            if (reason === ConnectionFailReason.NoSecrets) {
                root.passwordPrompt = "Password for " + root.pendingWifi.name;
                password.forceActiveFocus();
            } else
                Runtime.report("Wi-Fi connection failed: " + ConnectionFailReason.toString(reason));
        }
        function onConnectedChanged() {
            root.refresh();
        }
    }
    Instantiator {
        model: Networking.devices
        delegate: QtObject {
            required property var modelData
            property bool scan: root.visible && Runtime.menu === "wifi" && !Config.preview
            onScanChanged: if (modelData.type === DeviceType.Wifi)
                               modelData.scannerEnabled = scan
        }
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            if (Runtime.menu === "wifi")
                root.refresh();
        }
    }
    FolderListModel {
        id: folders
        folder: "file://" + encodeURIComponent(root.folderPath).replace(/%2F/g, "/")
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
        sortCaseSensitive: false
        showDirsFirst: true
        onCountChanged: if (Runtime.menu === "files")
                            root.refresh()
        onStatusChanged: if (status === FolderListModel.Ready && Runtime.menu === "files")
                             root.refresh()
    }
    ReferenceFile {
        id: reference
        sourcePath: Runtime.menu === "vim" ? Config.paths.vim : Runtime.menu === "lazyvim" ? Config.paths.lazyvim :
                                                                                             ""
        onReady: root.refresh()
    }
    Timer {
        interval: 5000
        repeat: true
        running: root.visible && Runtime.menu === "status"
        onTriggered: root.refresh()
    }
    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.visible) {
                         if (search.visible)
                             search.forceActiveFocus();
                         else
                             card.forceActiveFocus();
                     }
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: Runtime.closeMenu()
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Runtime.closeMenu()
    }
    Glass {
        id: card
        width: Math.min(root.fromBar ? 480 : 720, root.width - 32)
        height: Math.min(root.fromBar ? 560 : 650, root.height - 80)
        x: root.fromBar ? Math.max(16, Math.min(root.width - width - 16, Runtime.menuAnchorX - width / 2)) : (root.width - width) / 2
        y: root.fromBar ? (Config.preview ? root.height - Config.bar.height - Config.bar.margin - height - 12 : Config.bar.height + Config.bar.margin + 12) : (root.height - height) / 2
        color: Config.theme.solid
        transformOrigin: root.fromBar ? (Config.preview ? Item.Bottom : Item.Top) : Item.Center
        MouseArea {
            anchors.fill: parent
        }
        ColumnLayout {
            anchors {
                fill: parent
                margins: 22
            }
            spacing: 12
            RowLayout {
                Text {
                    text: root.heading
                    font.family: Config.theme.uiFont
                    font.pixelSize: 26
                    color: Config.theme.text
                    Layout.fillWidth: true
                }
                Chip {
                    text: "×"
                    onClicked: Runtime.closeMenu()
                }
            }
            Text {
                visible: Config.preview
                text: "Preview · device and session actions disabled"
                color: Config.theme.warning
                font.pixelSize: 12
            }
            TextField {
                id: search
                visible: Runtime.menu !== "calendar" && Runtime.menu !== "notifications"
                Layout.fillWidth: true
                placeholderTextColor: Config.theme.dim
                placeholderText: Runtime.menu === "files" ? root.folderPath : "Search…"
                color: Config.theme.text
                font.pixelSize: 16
                selectByMouse: true
                background: Rectangle {
                    radius: 9
                    color: Config.theme.surface
                    border.color: search.activeFocus ? Config.theme.accent : Config.theme.border
                }
                onAccepted: root.activate()
                Keys.onEscapePressed: Runtime.closeMenu()
                Keys.onDownPressed: list.currentIndex = Math.min(root.filtered.length - 1, list.currentIndex
                                                                 + 1)
                Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
            }
            Text {
                visible: Runtime.message !== ""
                text: Runtime.message
                color: Config.theme.warning
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Text {
                visible: Runtime.menu === "clipboard" && !Runtime.message
                text: root.clipboardBusy ? "Copying…" : "Select an entry to copy, then paste in your app."
                color: Config.theme.dim
                font.family: Config.theme.uiFont
                font.pixelSize: 13
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            ColumnLayout {
                visible: root.passwordPrompt !== ""
                Layout.fillWidth: true
                Text {
                    text: root.passwordPrompt
                    color: Config.theme.text
                }
                TextField {
                    id: password
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    color: Config.theme.text
                    background: Rectangle {
                        color: Config.theme.surface
                        radius: 8
                    }
                    onAccepted: {
                        if (root.pendingWifi && !Config.preview)
                            root.pendingWifi.connectWithPsk(text);
                        text = "";
                        root.passwordPrompt = "";
                    }
                    Keys.onEscapePressed: {
                        text = "";
                        root.passwordPrompt = "";
                        root.pendingWifi = null;
                        search.forceActiveFocus();
                    }
                }
                Chip {
                    text: "Connect"
                    onClicked: password.accepted()
                }
            }
            RowLayout {
                visible: root.confirmation !== ""
                Text {
                    text: "Confirm " + root.confirmation + "?"
                    color: Config.theme.warning
                    Layout.fillWidth: true
                }
                Chip {
                    text: "Cancel"
                    onClicked: root.confirmation = ""
                }
                Chip {
                    text: "Confirm"
                    onClicked: {
                        root.powerRequested(root.confirmation);
                        Runtime.closeMenu();
                    }
                }
            }
            RowLayout {
                visible: Runtime.menu === "notifications"
                Chip {
                    text: Preferences.dnd ? "DND on" : "DND off"
                    highlighted: Preferences.dnd
                    onClicked: Preferences.dnd = !Preferences.dnd
                }
                Chip {
                    text: "Clear all"
                    onClicked: Notifications.clear()
                }
            }
            ListView {
                id: list
                visible: Runtime.menu !== "notifications" && Runtime.menu !== "calendar"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filtered
                spacing: 4
                ScrollBar.vertical: ScrollBar {}
                delegate: ItemDelegate {
                    id: rowDelegate
                    required property var modelData
                    required property int index
                    width: list.width
                    height: subtitle.visible ? 65 : 44
                    highlighted: ListView.isCurrentItem
                    background: Rectangle {
                        radius: 9
                        color: rowDelegate.highlighted || rowDelegate.hovered ? Config.theme.surface :
                                                                                "transparent"
                        border.color: rowDelegate.highlighted ? Config.theme.accent : "transparent"
                    }
                    contentItem: RowLayout {
                        spacing: 10
                        Image {
                            visible: modelData.icon !== ""
                            source: modelData.icon ? Quickshell.iconPath(modelData.icon) : ""
                            Layout.preferredWidth: visible ? 26 : 0
                            Layout.preferredHeight: 26
                            fillMode: Image.PreserveAspectFit
                        }
                        ColumnLayout {
                            spacing: 3
                            Layout.fillWidth: true
                            Text {
                                text: modelData.title
                                color: Config.theme.text
                                font.family: Config.theme.uiFont
                                font.pixelSize: 16
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                id: subtitle
                                visible: modelData.subtitle !== ""
                                text: modelData.subtitle
                                color: Config.theme.dim
                                font.family: Config.theme.uiFont
                                font.pixelSize: 12
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                    onClicked: modelData.action()
                    onHoveredChanged: if (hovered)
                                          list.currentIndex = index
                }
                Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: search.text ? "No matches" : "Nothing here yet"
                    color: Config.theme.dim
                }
            }
            ScrollView {
                visible: Runtime.menu === "notifications"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Column {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: Notifications.entries
                        NotificationCard {
                            required property var modelData
                            width: parent.width
                            entry: modelData
                        }
                    }
                    Text {
                        visible: Notifications.entries.length === 0
                        text: "No notifications"
                        color: Config.theme.dim
                    }
                }
            }
            CalendarPanel {
                visible: Runtime.menu === "calendar"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
    ParallelAnimation {
        id: reveal
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: card
            property: "scale"
            from: 0.98
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
}
