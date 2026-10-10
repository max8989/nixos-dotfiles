pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../widgets"

ColumnLayout {
    id: root
    property date shown: new Date()
    function move(delta) {
        shown = new Date(shown.getFullYear(), shown.getMonth() + delta, 1);
    }
    function focusDefault() {
        previousMonth.forceActiveFocus(Qt.TabFocusReason);
    }
    Shortcut {
        sequence: "Left"
        enabled: root.visible
        onActivated: root.move(-1)
    }
    Shortcut {
        sequence: "Right"
        enabled: root.visible
        onActivated: root.move(1)
    }
    Shortcut {
        sequence: "Home"
        enabled: root.visible
        onActivated: root.shown = new Date()
    }
    RowLayout {
        Chip {
            id: previousMonth
            objectName: "calendarPrevious"
            text: "‹"
            Accessible.name: "Previous month"
            onClicked: root.move(-1)
        }
        Text {
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: Config.theme.text
            font.pixelSize: Config.fonts.display
            font.family: Config.theme.uiFont
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        Chip {
            text: "Today"
            onClicked: root.shown = new Date()
        }
        Chip {
            text: "›"
            Accessible.name: "Next month"
            onClicked: root.move(1)
        }
    }
    GridLayout {
        columns: 7
        Layout.fillWidth: true
        Layout.fillHeight: true
        Repeater {
            model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            Text {
                required property string modelData
                text: modelData
                color: Config.theme.dim
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
        Repeater {
            model: 42
            Rectangle {
                required property int index
                readonly property int day: index - ((new Date(root.shown.getFullYear(), root.shown.getMonth(), 1).getDay() + 6) % 7) + 1
                readonly property bool inMonth: day > 0 && day <= new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 0).getDate()
                readonly property bool today: inMonth && new Date().toDateString() === new Date(root.shown.getFullYear(), root.shown.getMonth(), day).toDateString()
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 9
                color: today ? Config.theme.accent : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.inMonth ? parent.day : ""
                    color: parent.today ? Config.theme.solid : Config.theme.text
                    font.pixelSize: Config.fonts.heading
                }
            }
        }
    }
}
