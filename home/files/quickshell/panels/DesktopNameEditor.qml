pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../services"
import "../widgets"

ColumnLayout {
    id: root
    property int workspaceId: Runtime.workspaceNameId
    readonly property bool ready: Preferences.initialized && workspaceId > 0
    signal finished
    spacing: Config.spacing.rowGap
    function reset() { nameField.text = Preferences.workspaceNames[workspaceId] || ""; }
    function focusDefault() {
        nameField.forceActiveFocus(Qt.TabFocusReason);
        nameField.selectAll();
    }
    function save() {
        if (ready && Preferences.setWorkspaceName(workspaceId, nameField.text))
            finished();
    }
    onVisibleChanged: if (visible) reset()
    onWorkspaceIdChanged: if (visible) reset()
    Connections {
        target: Preferences
        function onInitializedChanged() { if (root.visible) root.reset(); }
    }
    SettingsText {
        Layout.fillWidth: true
        text: root.workspaceId > 0 ? "Desktop " + root.workspaceId : "Choose a desktop in Manage desktops."
    }
    TextField {
        id: nameField
        objectName: "desktopNameInput"
        Layout.fillWidth: true
        enabled: root.ready
        Accessible.name: "Desktop name"
        placeholderText: "For example, Event config"
        maximumLength: 80
        selectByMouse: true
        color: Config.theme.text
        placeholderTextColor: Config.theme.dim
        font.family: Config.theme.uiFont
        font.pixelSize: Preferences.panelTextSize
        background: Rectangle {
            radius: 9
            color: Config.theme.surface
            border.color: nameField.activeFocus ? Config.theme.accent : Config.theme.border
        }
        onAccepted: root.save()
    }
    SettingsText {
        Layout.fillWidth: true
        caption: true
        text: "Names stay with desktop numbers and are saved across restarts. An empty name shows only the number."
    }
    RowLayout {
        Layout.fillWidth: true
        SettingsButton {
            Layout.fillWidth: true
            text: "Save"
            selected: true
            enabled: root.ready
            onClicked: root.save()
        }
        SettingsButton {
            Layout.fillWidth: true
            text: "Cancel"
            onClicked: root.finished()
        }
    }
    RowLayout {
        Layout.fillWidth: true
        SettingsButton {
            objectName: "desktopNameSwitch"
            Layout.fillWidth: true
            text: "Go to desktop"
            enabled: root.ready && !Config.preview
            onClicked: Workspaces.activate(root.workspaceId)
        }
        SettingsButton {
            objectName: "desktopNameClear"
            Layout.fillWidth: true
            text: "Clear name"
            enabled: root.ready && !!Preferences.workspaceNames[root.workspaceId]
            onClicked: {
                Preferences.setWorkspaceName(root.workspaceId, "");
                root.finished();
            }
        }
    }
    Item { Layout.fillHeight: true }
}
