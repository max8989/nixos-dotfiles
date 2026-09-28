pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import ".."

Button {
    id: root
    property string detail: ""
    property bool selected: false
    implicitHeight: detail ? label.implicitHeight + 22 : 38
    implicitWidth: Math.max(title.implicitWidth, description.implicitWidth) + 24
    padding: 12
    focusPolicy: Qt.TabFocus
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Accessible.description: detail
    contentItem: Column {
        id: label
        spacing: 3
        SettingsText {
            id: title
            width: parent.width
            text: root.text
            color: !root.enabled ? Config.theme.dim : root.selected ? Config.theme.accent : Config.theme.text
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
        SettingsText {
            id: description
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            caption: true
        }
    }
    background: Rectangle {
        radius: 8
        color: root.selected || root.down ? Qt.alpha(Config.theme.accent, 0.13) : root.hovered ? Config.theme.surface : "transparent"
        border.width: 1
        border.color: root.visualFocus ? Config.theme.accent : root.selected ? Qt.alpha(Config.theme.accent, 0.4) : Config.theme.border
    }
}
