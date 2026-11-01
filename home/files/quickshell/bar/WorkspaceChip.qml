pragma ComponentBehavior: Bound
import QtQuick
import ".."
import "../widgets"

Chip {
    id: root
    property bool attention: false
    property bool fullscreenWindow: false
    property int windowCount: 0
    compact: true
    foreground: attention ? Config.theme.urgent : highlighted ? Config.theme.accent
                                                        : windowCount ? Config.theme.text : Config.theme.dim
    Accessible.name: tipTitle + ", " + tip
    background: Rectangle {
        radius: root.fullscreenWindow ? 4 : height / 2
        color: Qt.alpha(root.attention ? Config.theme.urgent : Config.theme.text,
                        root.down ? Config.controls.pressedFillAlpha
                                  : root.highlighted ? Config.controls.selectedFillAlpha
                                  : root.hovered || root.visualFocus ? Config.controls.hoverFillAlpha : 0)
        border.width: root.fullscreenWindow || root.attention || root.visualFocus ? 1 : 0
        border.color: root.attention ? Config.theme.urgent : root.fullscreenWindow ? Config.theme.accent
                                    : Qt.alpha(Config.theme.text, Config.controls.hoverBorderAlpha)
        Behavior on color {
            ColorAnimation { duration: 140 }
        }
    }
    Rectangle {
        objectName: "workspaceAttention"
        visible: root.attention
        anchors { right: parent.right; top: parent.top; rightMargin: 3; topMargin: 3 }
        width: 5
        height: 5
        radius: width / 2
        color: Config.theme.urgent
    }
}
