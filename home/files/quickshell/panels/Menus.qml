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
import Quickshell.Services.SystemTray
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
    readonly property var pageRows: {
        switch (Runtime.menu) {
        case "controls": return search.text.trim() ? controls.all : controls.home;
        case "display": return controls.display;
        case "desktop": return controls.desktop;
        case "capture": return controls.capture;
        case "settings": return controls.settings;
        case "workspaces": return controls.workspaces;
        case "audio": return controls.audio.slice(0, 2).concat(rows);
        case "power": return controls.power.concat(controls.display.slice(1, 4), [controls.desktop[3]]);
        case "tray": return root.trayRows();
        case "trayMenu": return trayOpener.children.values.filter(e => !e.isSeparator).map(e => ({
            id: e.text, title: e.text.replace(/&(.)/g, "$1"), subtitle: e.enabled ? "" : "Unavailable",
            icon: "", submenu: e.hasChildren, value: e.checkState === Qt.Checked ? "✓" : "",
            action: () => {
                if (!e.enabled || Config.preview)
                    return;
                if (e.hasChildren)
                    root.openTrayMenu(e, e.text.replace(/&(.)/g, "$1"));
                else {
                    e.triggered();
                    Runtime.closeMenu();
                }
            }
        }));
        default: return rows;
        }
    }
    property var filtered: Logic.search(pageRows, search.text)
    property string selectionKey: ""
    property var trayHandle: null
    property string trayTitle: ""
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
                                           controls: "Desktop controls",
                                           display: "Display",
                                           desktop: "Desktop",
                                           capture: "Capture",
                                           settings: "Settings and shortcuts",
                                           workspaces: "Workspaces",
                                           tray: "System tray",
                                           trayMenu: trayTitle,
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
    ControlActions {
        id: controls
        onOpenMenu: name => root.openPage(name)
        onPowerRequested: action => root.requestPower(action)
    }
    QsMenuOpener {
        id: trayOpener
        menu: root.visible && Runtime.menu === "trayMenu" ? root.trayHandle : null
    }
    // Keep parent menus acquired while browsing their descendants.
    Instantiator {
        model: root.visible ? Runtime.menuHistory.filter(entry => entry.menu === "trayMenu" && entry.trayHandle).map(entry => entry.trayHandle) : []
        delegate: QsMenuOpener {
            required property var modelData
            menu: modelData
        }
    }
    function trayRows() {
        if (Config.preview)
            return [];
        var rows = [];
        SystemTray.items.values.forEach(item => {
            var title = item.title || item.tooltipTitle || item.id || "Application";
            if (!item.onlyMenu)
                rows.push(row("Open " + title, () => { item.activate(); Runtime.closeMenu(); }, "Tray application"));
            if (item.hasMenu)
                rows.push(row(title + " menu", () => openTrayMenu(item.menu, title), "Browse application actions"));
        });
        return rows;
    }
    function openTrayMenu(handle, title) {
        openPage("trayMenu");
        trayHandle = handle;
        trayTitle = title;
    }
    function openPage(name) {
        Runtime.menuHistory = Runtime.menuHistory.concat([{
            menu: Runtime.menu, query: search.text, index: list.currentIndex,
            trayHandle: trayHandle, trayTitle: trayTitle
        }]);
        // A nested application menu keeps the same page name.
        if (Runtime.menu === name) {
            search.text = "";
            selectionKey = "";
            focusTimer.restart();
        } else
            Runtime.menu = name;
    }
    function back() {
        var trail = Runtime.menuHistory;
        if (!trail.length) {
            Runtime.closeMenu();
            return;
        }
        var previous = trail[trail.length - 1];
        Runtime.menu = previous.menu;
        trayHandle = previous.trayHandle;
        trayTitle = previous.trayTitle;
        // Acquire the parent before releasing its retained menu opener.
        Runtime.menuHistory = trail.slice(0, -1);
        search.text = previous.query;
        selectIndex(previous.index);
        focusTimer.restart();
    }
    function dismissOrBack() {
        if (passwordPrompt) {
            password.text = "";
            passwordPrompt = "";
            pendingWifi = null;
            focusTimer.restart();
        } else if (confirmation) {
            confirmation = "";
            focusTimer.restart();
        } else
            back();
    }
    function selectIndex(index) {
        list.currentIndex = Math.max(0, Math.min(filtered.length - 1, index));
        var item = filtered[list.currentIndex];
        selectionKey = item ? item.id || item.title : "";
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }
    function adjust(direction) {
        var item = filtered[list.currentIndex];
        if (!item?.adjust || confirmation || passwordPrompt)
            return false;
        item.adjust(direction);
        focusTimer.restart();
        return true;
    }
    function requestPower(action) {
        if (Config.preview) {
            Runtime.report("Power actions are disabled in preview");
            return;
        }
        if (action === "lock" || action === "suspend") {
            powerRequested(action);
            Runtime.closeMenu();
        } else {
            confirmation = action;
            cancelPower.forceActiveFocus(Qt.TabFocusReason);
        }
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
                                                                                              => openPage("wifi"), Metrics.networkRate),
                     row("Bluetooth", () => openPage("bluetooth")), row("Audio and microphone", ()
                                                                             => openPage("audio")), row(
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
        if (confirmation || passwordPrompt)
            return;
        var item = filtered[list.currentIndex];
        if (item) {
            item.action();
            focusTimer.restart();
        }
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
    onFilteredChanged: {
        var index = filtered.findIndex(item => (item.id || item.title) === root.selectionKey);
        list.currentIndex = Math.max(0, index);
    }
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
            root.selectionKey = "";
            search.text = "";
            if (Runtime.menu === "controls" || Runtime.menu === "display")
                Display.refreshBrightness();
            if (!Runtime.menu) {
                root.trayHandle = null;
                root.trayTitle = "";
            }
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
        interval: 3000
        repeat: true
        running: root.visible && (Runtime.menu === "controls" || Runtime.menu === "display")
        onTriggered: Display.refreshBrightness()
    }
    Timer {
        id: focusTimer
        interval: 40
        onTriggered: if (root.visible) {
                         if (root.confirmation)
                             cancelPower.forceActiveFocus(Qt.TabFocusReason);
                         else if (root.passwordPrompt)
                             password.forceActiveFocus();
                         else if (search.visible)
                             search.forceActiveFocus();
                         else if (Runtime.menu === "notifications")
                             dndButton.forceActiveFocus(Qt.TabFocusReason);
                         else if (Runtime.menu === "calendar")
                             calendar.focusDefault();
                     }
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: root.dismissOrBack()
    }
    Shortcut {
        sequence: "Alt+Left"
        enabled: root.visible && Runtime.menuHistory.length > 0
        onActivated: root.dismissOrBack()
    }
    Shortcut {
        sequence: "Ctrl+L"
        enabled: root.visible && search.visible && search.enabled
        onActivated: { search.forceActiveFocus(); search.selectAll(); }
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
                Chip {
                    text: "‹"
                    visible: Runtime.menuHistory.length > 0
                    Accessible.name: "Back"
                    onClicked: root.dismissOrBack()
                }
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
                objectName: "menuSearch"
                visible: Runtime.menu !== "calendar" && Runtime.menu !== "notifications"
                enabled: !root.confirmation && !root.passwordPrompt
                Layout.fillWidth: true
                placeholderTextColor: Config.theme.dim
                placeholderText: Runtime.menu === "files" ? root.folderPath : Runtime.menu === "controls" ? "Search controls… volume, dnd, bluetooth" : "Search…"
                color: Config.theme.text
                font.pixelSize: 16
                selectByMouse: true
                background: Rectangle {
                    radius: 9
                    color: Config.theme.surface
                    border.color: search.activeFocus ? Config.theme.accent : Config.theme.border
                }
                onAccepted: root.activate()
                onTextEdited: { root.selectionKey = ""; root.selectIndex(0); }
                Keys.onDownPressed: root.selectIndex(list.currentIndex + 1)
                Keys.onUpPressed: root.selectIndex(list.currentIndex - 1)
                Keys.onLeftPressed: event => event.accepted = root.adjust(-1)
                Keys.onRightPressed: event => event.accepted = root.adjust(1)
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
                    objectName: "wifiPassword"
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
                        focusTimer.restart();
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
                    id: cancelPower
                    objectName: "cancelPower"
                    text: "Cancel"
                    onClicked: root.dismissOrBack()
                }
                Chip {
                    objectName: "confirmPower"
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
                    id: dndButton
                    objectName: "notificationDnd"
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
                objectName: "menuList"
                visible: Runtime.menu !== "notifications" && Runtime.menu !== "calendar"
                enabled: !root.confirmation && !root.passwordPrompt
                Layout.fillWidth: true
                Layout.fillHeight: true
                opacity: enabled ? 1 : 0.4
                clip: true
                keyNavigationEnabled: true
                Keys.onReturnPressed: root.activate()
                Keys.onEnterPressed: root.activate()
                Keys.onLeftPressed: event => event.accepted = root.adjust(-1)
                Keys.onRightPressed: event => event.accepted = root.adjust(1)
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
                    focusPolicy: Qt.NoFocus
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
                        Text {
                            text: rowDelegate.modelData.value || (rowDelegate.modelData.submenu ? "›" : "")
                            color: Config.theme.accent
                            font.family: Config.theme.uiFont
                            font.pixelSize: 14
                            textFormat: Text.PlainText
                        }
                    }
                    onClicked: { root.selectIndex(index); root.activate(); }
                    onHoveredChanged: if (hovered)
                                          root.selectIndex(index)
                }
                Label {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: search.text ? "No matches" : Runtime.menu === "tray" ? "No tray applications" : "Nothing here yet"
                    color: Config.theme.dim
                }
            }
            ScrollView {
                id: notificationScroll
                visible: Runtime.menu === "notifications"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                Column {
                    id: notificationColumn
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: Notifications.entries
                        NotificationCard {
                            required property var modelData
                            width: parent.width
                            entry: modelData
                            onFocusRequested: item => {
                                var position = item.mapToItem(notificationColumn, 0, 0).y;
                                var flickable = notificationScroll.contentItem as Flickable;
                                if (!flickable)
                                    return;
                                if (position < flickable.contentY)
                                    flickable.contentY = position;
                                else if (position + item.height > flickable.contentY + flickable.height)
                                    flickable.contentY = position + item.height - flickable.height;
                            }
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
                id: calendar
                objectName: "menuCalendar"
                visible: Runtime.menu === "calendar"
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Config.theme.dim
                font.family: Config.theme.uiFont
                font.pixelSize: 12
                text: root.confirmation || root.passwordPrompt ? "Tab  Move focus    Enter / Space  Activate    Esc  Cancel"
                    : Runtime.menu === "calendar" ? "← →  Month    Home  Today    Tab  Move focus    Esc  Back / close"
                    : Runtime.menu === "notifications" ? "Tab / Shift+Tab  Move focus    Enter / Space  Activate    Esc  Back / close"
                    : "↑ ↓  Select    Enter  Open / toggle    ← →  Adjust    Esc  Back / close"
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
