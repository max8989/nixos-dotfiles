pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import ".."

Button {
    id: root
    property string tip: ""
    property string tipTitle: ""
    property bool selected: false
    property bool tipDismissed: false
    property color foreground: highlighted || selected ? Config.theme.accent : Config.theme.text
    signal rightClicked
    signal scrolled(int direction)
    implicitHeight: 30
    implicitWidth: Math.max(30, label.implicitWidth + 18)
    hoverEnabled: true
    // Mouse clicks should not leave the keyboard focus ring behind.
    focusPolicy: Qt.TabFocus
    padding: 7
    onPressed: tipDismissed = true
    onHoveredChanged: if (!hovered)
        tipDismissed = false
    contentItem: Text {
        id: label
        text: root.text
        color: root.enabled ? root.foreground : Config.theme.dim
        font.family: Config.theme.font
        font.pixelSize: Config.theme.fontSize
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        elide: Text.ElideRight
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    background: Rectangle {
        radius: 10
        color: root.down ? Qt.alpha(Config.theme.accent, 0.24) : root.highlighted || root.selected ? Qt.alpha(Config.theme.accent, 0.14) : root.hovered ? Qt.alpha(Config.theme.text, 0.08) : "transparent"
        border.color: root.visualFocus ? Config.theme.accent : "transparent"
        border.width: 1
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    HoverTip {
        target: root
        title: root.tipTitle
        text: root.tip
        active: root.hovered && root.enabled && !root.down && !root.tipDismissed && !Runtime.menu && !Runtime.locked
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: root.tipDismissed = true
        onClicked: root.rightClicked()
        onWheel: function (wheel) {
            root.tipDismissed = true;
            root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1);
        }
    }
}
