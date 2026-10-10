pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import ".."

PopupWindow {
    id: root
    required property Item target
    property string title: ""
    property string text: ""
    property bool active: false
    property bool above: Config.preview
    property bool ready: false

    visible: active && ready && (title.length > 0 || text.length > 0)
    color: "transparent"
    // A tooltip never takes focus or intercepts clicks on the desktop.
    mask: Region {}
    anchor.item: target
    anchor.edges: above ? Edges.Top : Edges.Bottom
    anchor.gravity: above ? Edges.Top : Edges.Bottom
    // Negative margins expand the anchor beyond the button's bounds.
    anchor.margins.top: -10
    anchor.margins.bottom: -10
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY
    implicitWidth: Math.ceil(Math.min(320, Math.max(titleText.implicitWidth, bodyText.implicitWidth)) + 32)
    implicitHeight: Math.ceil(content.implicitHeight + 26)

    onActiveChanged: {
        ready = false;
        if (active)
            delay.restart();
        else
            delay.stop();
    }
    onVisibleChanged: if (visible)
        reveal.restart()
    onWidthChanged: if (visible)
        anchor.updateAnchor()
    onHeightChanged: if (visible)
        anchor.updateAnchor()

    Timer {
        id: delay
        interval: 380
        onTriggered: root.ready = true
    }
    Glass {
        id: card
        anchors.fill: parent
        anchors.margins: 2
        surface: "tooltip"
        Column {
            id: content
            anchors.centerIn: parent
            width: parent.width - 28
            spacing: 5
            Text {
                id: titleText
                visible: text.length > 0
                width: parent.width
                text: root.title
                color: Config.theme.text
                font.family: Config.theme.uiFont
                font.pixelSize: Config.fonts.body
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
            }
            Text {
                id: bodyText
                visible: text.length > 0
                width: parent.width
                text: root.text
                color: root.title ? Config.theme.dim : Config.theme.text
                font.family: Config.theme.uiFont
                font.pixelSize: Config.fonts.body
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 10
                elide: Text.ElideRight
            }
        }
    }
    ParallelAnimation {
        id: reveal
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: card
            property: "scale"
            from: 0.97
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
}
