pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import ".."

Button {
    id: root
    property string detail: ""
    property bool selected: false
    implicitHeight: detail ? label.implicitHeight + Config.spacing.controlPaddingY * 2 : Config.spacing.controlHeight
    implicitWidth: Math.max(title.implicitWidth, description.implicitWidth) + 24
    padding: Config.spacing.controlPaddingY
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
        radius: 4
        color: Qt.alpha(Config.theme.text, root.down ? Config.controls.pressedFillAlpha : root.selected ? Config.controls.selectedFillAlpha : root.hovered || root.visualFocus ? Config.controls.hoverFillAlpha : Config.controls.normalFillAlpha)
        border.width: root.selected ? 0 : 1
        border.color: Qt.alpha(Config.theme.text, root.visualFocus || root.hovered ? Config.controls.hoverBorderAlpha : Config.controls.normalBorderAlpha)
    }
}
