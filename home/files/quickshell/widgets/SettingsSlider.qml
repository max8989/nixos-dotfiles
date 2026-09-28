pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    property string title: ""
    property string readout: ""
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property alias slider: slider
    signal moved(real value)
    spacing: 3
    function focusDefault() { slider.forceActiveFocus(Qt.TabFocusReason); }
    RowLayout {
        Layout.fillWidth: true
        SettingsText { text: root.title; Layout.fillWidth: true; caption: true }
        SettingsText { text: root.readout; caption: true }
    }
    Slider {
        id: slider
        objectName: root.objectName + "Slider"
        Layout.fillWidth: true
        implicitHeight: 32
        from: 0
        to: 100
        stepSize: 5
        snapMode: Slider.SnapAlways
        focusPolicy: Qt.StrongFocus
        Accessible.name: root.title
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 5
            radius: 3
            color: Config.theme.surface
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 3
                color: slider.enabled ? Config.theme.accent : Config.theme.dim
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 16
            height: 16
            radius: 8
            color: slider.enabled ? Config.theme.accent : Config.theme.dim
            border.width: slider.activeFocus ? 3 : 1
            border.color: slider.activeFocus ? Config.theme.text : Config.theme.solid
        }
    }
}
