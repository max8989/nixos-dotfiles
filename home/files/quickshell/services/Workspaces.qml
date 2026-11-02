pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    property var compositor: Hyprland
    readonly property int currentId: compositor.focusedMonitor?.activeWorkspace?.id || 0
    readonly property var entries: Logic.workspaceEntries(compositor.workspaces.values, Preferences.workspaceNames)
    function title(id) {
        var name = Preferences.workspaceNames[id] || "";
        return "Desktop " + id + (name ? " · " + name : "");
    }
    function activate(id) {
        if (Config.preview || Runtime.locked || !Logic.validWorkspaceId(id))
            return;
        var workspace = compositor.workspaces.values.find(workspace => workspace.id === id);
        if (workspace)
            workspace.activate();
        else
            compositor.dispatch(compositor.usingLua ? "hl.dsp.focus({ workspace = " + id + " })" : "workspace " + id);
        Runtime.closeMenu();
    }
}
