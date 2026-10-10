pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import ".."

Button {
    id: root
    property string tip: ""
    property string tipTitle: ""
    property bool selected: false
    property bool compact: false
    property bool tipDismissed: false
    property color foreground: highlighted || selected ? Config.theme.accent : Config.theme.text
    // Optional status tint: colored fill and outline (transparent = none).
    property color tint: "transparent"
    signal rightClicked
    signal scrolled(int direction)
    implicitHeight: compact ? Config.bar.height - 8 : Config.spacing.controlHeight
    implicitWidth: Math.max(compact ? 30 : 28, label.implicitWidth + (compact ? 18 : Config.spacing.controlPaddingX * 2))
    hoverEnabled: true
    // Mouse clicks should not leave the keyboard focus ring behind.
    focusPolicy: Qt.TabFocus
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    padding: compact ? 7 : Config.spacing.controlPaddingY
    onPressed: tipDismissed = true
    onHoveredChanged: if (!hovered)
        tipDismissed = false
    contentItem: Text {
        id: label
        text: root.text
        color: root.enabled ? root.foreground : Config.theme.dim
        font.family: Config.theme.font
        font.pixelSize: root.compact ? (Config.bar.fontSize || Config.fonts.title) : Config.theme.fontSize
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
        radius: root.compact ? height / 2 : 4
        color: Qt.alpha(root.tint.a > 0 ? root.tint : Config.theme.text, root.down ? Config.controls.pressedFillAlpha : root.highlighted || root.selected ? Config.controls.selectedFillAlpha : root.hovered || root.visualFocus ? Config.controls.hoverFillAlpha : root.compact ? 0 : Config.controls.normalFillAlpha)
        border.color: root.tint.a > 0 ? root.tint : root.compact && !root.visualFocus ? "transparent" : Qt.alpha(Config.theme.text, root.hovered || root.visualFocus ? Config.controls.hoverBorderAlpha : Config.controls.normalBorderAlpha)
        border.width: root.highlighted || root.selected || root.compact && !root.visualFocus ? 0 : 1
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
