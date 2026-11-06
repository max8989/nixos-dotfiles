pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../widgets"
import "../Logic.js" as Logic

ColumnLayout {
    id: root
    property bool active: false
    property bool choosing: false
    property bool busy: false
    property bool loading: false
    property bool importExpanded: false
    property var entries: []
    property string currentId: "default"
    property string selectedId: ""
    property string status: ""
    property var pendingDelete: null
    property int serial: 0
    readonly property var filtered: entries.filter(entry => entry.builtin || entry.name.toLowerCase().includes(search.text.trim().toLowerCase()))
    readonly property var selected: filtered.find(entry => entry.id === selectedId) || null
    spacing: Config.spacing.rowGap

    function focusDefault() { if (pendingDelete) cancelDelete.forceActiveFocus(Qt.TabFocusReason); else search.forceActiveFocus(); }
    function dismiss() {
        if (pendingDelete) pendingDelete = null;
        else if (importExpanded) importExpanded = false;
        else return false;
        focusDefault();
        return true;
    }
    function refresh(preferred) {
        var token = ++serial;
        loading = true;
        Runtime.run([Config.bin.theme, "wallpaper", "library", Config.selectedTheme], function(code, out) {
            if (token !== root.serial || !root.active) return;
            root.loading = false;
            var library = Logic.parseJson(out, null);
            if (code || !library?.entries) { root.status = "Wallpapers could not be loaded. Reopen the gallery to retry."; return; }
            root.entries = library.entries;
            root.currentId = library.current;
            var id = preferred || root.selectedId || library.current;
            root.selectedId = root.filtered.some(entry => entry.id === id) ? id : "default";
        });
    }
    function mutate(args, complete) {
        if (busy || choosing || Config.preview) return;
        busy = true;
        var token = ++serial;
        Runtime.run([Config.bin.theme, "wallpaper"].concat(args), function(code, out) {
            root.busy = false;
            if (token !== root.serial || !root.active || Runtime.locked) return;
            complete(code, out);
        });
    }
    function applySelection() {
        if (!selected || pendingDelete) return;
        var args = selected.builtin ? ["reset", Config.selectedTheme] : ["select", selected.id, Config.selectedTheme];
        mutate(args, function(code) {
            if (code) root.status = "Wallpaper could not be changed. Try importing the image again.";
            else Runtime.closeMenu();
        });
    }
    function importPaths(paths) {
        if (!paths.length) { focusDefault(); return; }
        mutate(["import"].concat(paths), function(code, out) {
            var results = Logic.parseJson(out, []);
            var imported = results.filter(entry => entry.status === "imported");
            var duplicates = results.filter(entry => entry.status === "duplicate");
            var failed = results.filter(entry => entry.status === "error");
            root.status = results.length ? imported.length + " imported · " + duplicates.length + " already saved" + (failed.length ? " · " + failed.length + " could not be imported (PNG, JPEG, WebP or BMP required)" : "") : "Images could not be imported. Choose readable PNG, JPEG, WebP or BMP files.";
            search.text = "";
            root.refresh(imported[0]?.id || duplicates[0]?.id || root.selectedId);
            root.focusDefault();
        });
    }
    function choose(mode) {
        if (busy || choosing || Config.preview) return;
        importExpanded = false;
        choosing = true;
        var token = ++serial;
        var folder = Preferences.wallpaperFolder || (Config.paths.home + "/Downloads");
        Runtime.run([Config.bin.wallpaperImport, mode, folder], function(code, out) {
            root.choosing = false;
            if (token !== root.serial || !root.active || Runtime.locked) return;
            var result = Logic.parseJson(out, null);
            if (code || !result?.paths) { root.status = "The image picker could not be opened. Try importing again."; root.focusDefault(); return; }
            if (result.folder) Preferences.wallpaperFolder = result.folder;
            root.importPaths(result.paths);
        });
    }
    function requestDelete() {
        if (!selected || selected.builtin || busy || choosing) return;
        pendingDelete = selected;
        Qt.callLater(() => { if (root.pendingDelete) cancelDelete.forceActiveFocus(Qt.TabFocusReason); });
    }
    function confirmDelete() {
        if (!pendingDelete) return;
        mutate(["delete", pendingDelete.id], function(code) {
            root.pendingDelete = null;
            root.status = code ? "Wallpaper could not be deleted. Reopen the gallery and try again." : "Wallpaper deleted. Original files were kept.";
            root.refresh("default");
            root.focusDefault();
        });
    }
    function moveSelection(delta) {
        var index = Math.max(0, Math.min(filtered.length - 1, grid.currentIndex + delta));
        selectedId = filtered[index]?.id || "default";
        grid.positionViewAtIndex(index, GridView.Contain);
    }
    onActiveChanged: {
        serial++;
        pendingDelete = null;
        importExpanded = false;
        if (active) { selectedId = ""; search.text = ""; status = ""; refresh(""); }
    }
    Connections {
        target: Config
        function onSelectedThemeChanged() { if (root.active) { root.pendingDelete = null; root.selectedId = ""; search.text = ""; root.refresh(""); } }
    }
    Flow {
        id: toolbar
        Layout.fillWidth: true
        spacing: Config.spacing.controlGap
        enabled: !root.busy && !root.loading && !root.pendingDelete
        SettingsButton { objectName: "wallpaperImport"; text: "Import ▾"; onClicked: root.importExpanded = !root.importExpanded }
        SettingsButton { objectName: "wallpaperApply"; text: "Change wallpaper"; enabled: !!root.selected; onClicked: root.applySelection() }
        SettingsButton { objectName: "wallpaperDelete"; text: "Delete"; enabled: !!root.selected && !root.selected.builtin; onClicked: root.requestDelete() }
    }
    Flow {
        Layout.fillWidth: true
        visible: root.importExpanded
        spacing: Config.spacing.controlGap
        SettingsButton { objectName: "wallpaperChooseFiles"; text: "Choose files…"; onClicked: root.choose("dialog") }
        SettingsButton { objectName: "wallpaperChooseSuperfile"; text: "Choose in superfile…"; onClicked: root.choose("superfile") }
    }
    TextField {
        id: search
        objectName: "wallpaperSearch"
        Layout.fillWidth: true
        enabled: !root.busy && !root.pendingDelete
        placeholderText: "Search saved wallpapers…"
        Accessible.name: "Search saved wallpapers"
        color: Config.theme.text
        placeholderTextColor: Config.theme.dim
        font.family: Config.theme.uiFont
        selectByMouse: true
        background: Rectangle { color: Config.theme.surface; radius: 6; border.color: search.activeFocus ? Config.theme.accent : Config.theme.border }
        onTextEdited: root.selectedId = root.filtered[search.text.trim() && root.filtered.length > 1 ? 1 : 0]?.id || "default"
        onAccepted: root.applySelection()
        Keys.onDownPressed: grid.forceActiveFocus()
    }
    SettingsText {
        Layout.fillWidth: true
        caption: true
        text: root.loading ? "Loading wallpapers…" : root.busy ? "Saving…" : root.status || "Saved for " + Config.theme.displayName + ". Import adds images; Change wallpaper applies your selection."
    }
    ColumnLayout {
        visible: !!root.pendingDelete
        Layout.fillWidth: true
        SettingsText {
            Layout.fillWidth: true
            text: root.pendingDelete ? "Delete “" + root.pendingDelete.name + "” from the collection? Original files will be kept." + (root.pendingDelete.usedBy.length ? " Restore theme defaults for: " + root.pendingDelete.usedBy.map(id => Config.data.themes[id]?.displayName || id).join(", ") + "." : "") : ""
        }
        RowLayout {
            SettingsButton { id: cancelDelete; objectName: "wallpaperCancelDelete"; text: "Cancel"; enabled: !root.busy; onClicked: root.dismiss() }
            SettingsButton { objectName: "wallpaperConfirmDelete"; text: "Delete wallpaper"; enabled: !root.busy; onClicked: root.confirmDelete() }
        }
    }
    GridView {
        id: grid
        objectName: "wallpaperGrid"
        Layout.fillWidth: true
        Layout.fillHeight: true
        readonly property int columns: Math.max(1, Math.floor(width / 195))
        cellWidth: width / columns
        cellHeight: cellWidth * 9 / 16 + 68
        clip: true
        enabled: !root.busy && !root.pendingDelete
        activeFocusOnTab: true
        keyNavigationEnabled: false
        currentIndex: Math.max(0, root.filtered.findIndex(entry => entry.id === root.selectedId))
        model: root.filtered
        ScrollBar.vertical: ScrollBar {}
        Keys.onLeftPressed: root.moveSelection(-1)
        Keys.onRightPressed: root.moveSelection(1)
        Keys.onUpPressed: root.moveSelection(-columns)
        Keys.onDownPressed: root.moveSelection(columns)
        Keys.onReturnPressed: root.applySelection()
        Keys.onEnterPressed: root.applySelection()
        Keys.onDeletePressed: root.requestDelete()
        delegate: WallpaperCard {
            required property var modelData
            entry: modelData
            width: grid.cellWidth - Config.spacing.controlGap
            height: grid.cellHeight - Config.spacing.controlGap
            chosen: modelData.id === root.selectedId
            current: modelData.id === root.currentId
            onClicked: { root.selectedId = modelData.id; grid.forceActiveFocus(); }
        }
    }
    SettingsText {
        visible: root.entries.length === 1 && !root.loading
        Layout.fillWidth: true
        text: "Your collection is empty. Import images to get started."
        caption: true
    }
}
