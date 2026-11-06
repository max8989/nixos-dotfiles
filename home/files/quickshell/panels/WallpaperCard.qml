pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../widgets"

ItemDelegate {
    id: root
    required property var entry
    property bool chosen: false
    property bool current: false
    focusPolicy: Qt.NoFocus
    padding: 6
    Accessible.name: entry.name + (current ? ", current wallpaper" : "")
    Accessible.description: entry.builtin ? "Bundled wallpaper. Cannot be deleted." : "Select, then Change wallpaper to apply."
    contentItem: ColumnLayout {
        spacing: 4
        Image {
            objectName: "wallpaperThumbnail"
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: "file://" + encodeURIComponent(root.entry.path).replace(/%2F/g, "/")
            sourceSize: Qt.size(384, 216)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            clip: true
        }
        SettingsText {
            Layout.fillWidth: true
            text: root.entry.name
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
        SettingsText {
            Layout.fillWidth: true
            caption: true
            text: root.current ? "✓ Current" : root.entry.builtin ? "Bundled · protected" : "Saved wallpaper"
            color: root.current ? Config.theme.accent : Config.theme.dim
            wrapMode: Text.NoWrap
        }
    }
    background: Rectangle {
        radius: 6
        color: Qt.alpha(Config.theme.text, root.chosen ? Config.controls.selectedFillAlpha : root.hovered ? Config.controls.hoverFillAlpha : Config.controls.normalFillAlpha)
        border.width: root.chosen ? 2 : 1
        border.color: root.chosen ? Config.theme.accent : Qt.alpha(Config.theme.border, Config.controls.normalBorderAlpha)
    }
}
