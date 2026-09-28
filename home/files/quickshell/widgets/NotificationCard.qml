pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

Glass {
    id: root
    required property var entry
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
            Text {
                text: root.entry.notification ? root.entry.notification.appName : root.entry.app
                color: Config.theme.dim
                font.family: Config.theme.uiFont
                font.pixelSize: 12
                textFormat: Text.PlainText
                Layout.fillWidth: true
                elide: Text.ElideRight
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
            text: root.entry.notification ? root.entry.notification.summary : root.entry.title
            color: Config.theme.text
            font.bold: true
            font.family: Config.theme.uiFont
            font.pixelSize: 16
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Text {
            text: root.entry.notification ? root.entry.notification.body : root.entry.body
            color: Config.theme.text
            font.family: Config.theme.uiFont
            font.pixelSize: 14
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 8
            elide: Text.ElideRight
            Layout.fillWidth: true
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
