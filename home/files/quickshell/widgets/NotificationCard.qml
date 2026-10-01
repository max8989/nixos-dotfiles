pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Glass {
    id: root
    required property var entry
    property bool expandable: false
    property bool expanded: false
    objectName: "notificationCard"
    signal focusRequested(var item)
    implicitHeight: content.implicitHeight + 24
    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: root.entry.notification ? root.entry.notification.appName : root.entry.app
                color: Config.theme.dim
                font.family: Config.theme.uiFont
                font.pixelSize: 12
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                text: root.entry.time ? Qt.formatTime(new Date(root.entry.time), "hh:mm") : ""
                color: Config.theme.dim
                font.family: Config.theme.uiFont
                font.pixelSize: 12
            }
            Chip {
                text: "×"
                Accessible.name: "Dismiss notification"
                onActiveFocusChanged: if (activeFocus) root.focusRequested(this)
                tip: "Dismiss"
                onClicked: Notifications.dismiss(root.entry.id)
            }
        }
        Text {
            id: summary
            text: root.entry.notification ? root.entry.notification.summary : root.entry.title
            color: Config.theme.text
            font.bold: true
            font.family: Config.theme.uiFont
            font.pixelSize: 16
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.expanded ? 2147483647 : 3
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Text {
            id: body
            text: root.entry.notification ? root.entry.notification.body : root.entry.body
            visible: text.length > 0
            color: Config.theme.text
            font.family: Config.theme.uiFont
            font.pixelSize: 14
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: root.expanded ? 2147483647 : 6
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
        Chip {
            objectName: "notificationExpand"
            visible: root.expandable && (root.expanded || summary.truncated || body.truncated)
            text: root.expanded ? "Show less" : "Show more"
            foreground: Config.theme.accent
            onActiveFocusChanged: if (activeFocus) root.focusRequested(this)
            onClicked: {
                root.expanded = !root.expanded;
                if (!root.expanded)
                    Qt.callLater(() => root.focusRequested(this));
            }
        }
        Image {
            source: root.entry.image || ""
            visible: source.toString().length > 0
            Layout.preferredHeight: visible ? 100 : 0
            Layout.fillWidth: true
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.entry.notification ? root.entry.notification.actions : []
                Chip {
                    required property var modelData
                    onActiveFocusChanged: if (activeFocus) root.focusRequested(this)
                    text: modelData.text
                    onClicked: Notifications.invoke(root.entry.id, modelData)
                }
            }
        }
    }
}
