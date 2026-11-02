pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "WindowActivity.js" as Activity

Singleton {
    id: root
    property var compositor: ({ windows: [], activeAddress: "" })
    readonly property var snapshot: compositor.windows
    property bool refreshing: false
    property bool refreshAgain: false
    property var notificationEntries: []
    property bool updatingAttention: false
    onNotificationEntriesChanged: refreshDelay.restart()
    // The compositor snapshot also covers XWayland and internally fullscreen
    // windows whose native Wayland handles do not expose their current state.
    property var clients: snapshot.map(ipc => {
            const nativeWindow = Hyprland.toplevels.values.find(toplevel =>
                "0x" + toplevel.address === ipc.address);
            return {
                address: ipc.address,
                pid: ipc.pid || 0,
                class: ipc.class || "",
                initialClass: ipc.initialClass || "",
                appId: nativeWindow?.wayland?.appId || ipc.class || "",
                workspace: { name: ipc.workspace?.name || ipc.workspace?.address || "" },
                mapped: ipc.mapped !== false,
                hidden: !!ipc.hidden,
                focusHistoryID: ipc.focusHistoryID,
                urgent: !!ipc.urgent || !!nativeWindow?.urgent,
                tags: ipc.tags || [],
                // Super+D maximized and Super+F fullscreen both get a square.
                fullscreen: (ipc.fullscreen & 3) !== 0,
                activated: ipc.address === root.compositor.activeAddress
            };
        })
    readonly property string activeAddress: clients.find(client => client.activated)?.address || ""
    readonly property string activeWorkspace: clients.find(client => client.activated)?.workspace.name || ""

    function refresh() {
        if (Config.preview || !Config.valid)
            return;
        if (refreshing) {
            refreshAgain = true;
            return;
        }
        refreshing = true;
        Runtime.run([Config.bin.hyprctl, "-j", "clients"], function(code, out) {
            let next = root.snapshot;
            if (!code) {
                try {
                    const parsed = JSON.parse(out);
                    if (Array.isArray(parsed))
                        next = parsed;
                } catch (error) {
                    console.warn("Could not read workspace window state");
                }
            }
            // MRU rank zero can still belong to another workspace when focus
            // moves to an empty workspace. Read the actual focused window.
            Runtime.run([Config.bin.hyprctl, "-j", "activewindow"], function(focusCode, focusOut) {
                let address = "";
                if (!focusCode) {
                    try {
                        address = JSON.parse(focusOut).address || "";
                    } catch (error) {
                        console.warn("Could not read the focused window");
                    }
                }
                root.compositor = { windows: next, activeAddress: address };
                root.refreshing = false;
                root.syncAttention();
                if (root.refreshAgain) {
                    root.refreshAgain = false;
                    refreshDelay.restart();
                }
            });
        });
    }
    function syncAttention() {
        if (Config.preview || !Config.valid || updatingAttention)
            return;
        const changes = Activity.attentionChanges(clients, notificationEntries, activeAddress);
        if (!changes.length)
            return;
        const commands = changes.map(change => 'dispatch hl.dsp.window.tag({window = "address:' + change.address
            + '", tag = "' + (change.attention ? "+" : "-") + 'quickshell-notification"})');
        updatingAttention = true;
        Runtime.run([Config.bin.hyprctl, "--batch", commands.join("; ")], function(code) {
            root.updatingAttention = false;
            if (code)
                console.warn("Could not update notification window borders");
            else
                refreshDelay.restart();
        });
    }
    Component.onCompleted: refreshDelay.restart()
    Timer {
        id: refreshDelay
        interval: 80
        onTriggered: root.refresh()
    }
    Connections {
        target: Hyprland
        function onRawEvent() {
            refreshDelay.restart();
        }
    }
    Connections {
        target: Config
        function onValidChanged() {
            refreshDelay.restart();
        }
    }
    function target(entry) {
        return Activity.notificationTarget(entry, clients);
    }
    function workspaceState(name, entries) {
        return Activity.workspaceState(name, clients, entries);
    }
    function focus(client) {
        if (!client || !/^0x[0-9a-f]+$/i.test(client.address) || Runtime.locked || Config.preview)
            return false;
        Runtime.closeMenu();
        // Use the same explicit focus dispatcher as the recent-window picker.
        Runtime.run([Config.bin.hyprctl, "dispatch", 'hl.dsp.focus({window = "address:' + client.address + '"})'], function(code) {
            if (code)
                Runtime.report("That window is no longer available");
        });
        return true;
    }
}
