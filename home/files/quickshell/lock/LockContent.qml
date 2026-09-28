pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import ".."
import "../widgets"
import "../services"

Item {
    id: root
    property string snapshot: ""
    property string authMessage: ""
    property bool busy: false
    property string hostname: ""
    signal submitted(string password)
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: root.hostname = text().trim()
    }
    Image {
        id: backdrop
        anchors.fill: parent
        source: root.snapshot
        visible: false
        fillMode: Image.PreserveAspectCrop
    }
    MultiEffect {
        anchors.fill: parent
        source: backdrop
        blurEnabled: true
        blurMax: 64
        blur: 1
        brightness: -0.45
        saturation: -0.2
    }
    Rectangle {
        anchors.fill: parent
        color: "#550a0a12"
    }
    readonly property string phrase: {
        var lines = Reminders.phrases.trim().split("\n");
        var day = Math.floor((clock.date - new Date(clock.date.getFullYear(), 0, 0)) / 86400000);
        return lines.length ? lines[day % lines.length].split("").join("\n") : "";
    }
    Text {
        anchors {
            left: parent.left
            leftMargin: 36
            verticalCenter: parent.verticalCenter
        }
        text: root.phrase
        color: Config.theme.text
        font.pixelSize: 26
        visible: root.width > 900
    }
    Column {
        anchors {
            right: parent.right
            top: parent.top
            margins: 28
        }
        spacing: 8
        Text {
            anchors.right: parent.right
            text: "電池: " + (Battery.present ? Battery.percent + "%" : "AC") + "  記憶體: " + Metrics.ram.percent
                  + "%"
            color: Config.theme.text
            font.pixelSize: 15
        }
        Text {
            anchors.right: parent.right
            text: Reminders.weather
            color: Config.theme.dim
            font.pixelSize: 14
        }
    }
    Glass {
        anchors.centerIn: parent
        width: Math.min(460, root.width - 48)
        height: 400
        border.color: Config.theme.accent
        ColumnLayout {
            anchors {
                fill: parent
                margins: 32
            }
            spacing: 16
            Text {
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                color: Config.theme.accent
                font.family: Config.theme.font
                font.pixelSize: 48
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: Qt.formatDate(clock.date, "yyyy年M月d日") + "  " + ["星期日", "星期一", "星期二", "星期三", "星期四",
                                                                       "星期五", "星期六"][clock.date.getDay()]
                color: Config.theme.text
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: (Config.data.user || "") + "@" + root.hostname
                color: Config.theme.dim
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }
            TextField {
                id: password
                Layout.fillWidth: true
                enabled: !root.busy
                focus: true
                echoMode: TextInput.Password
                placeholderTextColor: Config.theme.dim
                placeholderText: "請輸入密碼"
                color: Config.theme.text
                font.pixelSize: 18
                horizontalAlignment: TextInput.AlignHCenter
                background: Rectangle {
                    radius: 12
                    color: Config.theme.surface
                    border.color: password.activeFocus ? Config.theme.accent : Config.theme.border
                    border.width: 2
                }
                onAccepted: {
                    root.submitted(text);
                    text = "";
                }
                Keys.onEscapePressed: text = ""
                Component.onCompleted: forceActiveFocus()
            }
            Text {
                text: root.busy ? "正在驗證…" : root.authMessage
                color: Config.theme.urgent
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 14
            }
            Chip {
                text: "解鎖"
                enabled: !root.busy
                Layout.alignment: Qt.AlignHCenter
                onClicked: password.accepted()
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
    Column {
        anchors {
            right: parent.right
            rightMargin: 32
            verticalCenter: parent.verticalCenter
        }
        width: Math.min(280, root.width * 0.22)
        spacing: 10
        visible: root.width > 1250
        Text {
            text: "待辦事項"
            color: Config.theme.accent
            font.pixelSize: 20
        }
        Repeater {
            model: Reminders.items.slice(0, 10)
            Text {
                required property string modelData
                width: parent.width
                text: "• " + modelData
                color: Config.theme.text
                font.pixelSize: 14
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
        }
    }
    RowLayout {
        anchors {
            bottom: parent.bottom
            bottomMargin: 36
            horizontalCenter: parent.horizontalCenter
        }
        Image {
            source: Media.player?.trackArtUrl || ""
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            fillMode: Image.PreserveAspectCrop
            visible: source.toString() !== ""
            asynchronous: true
        }
        Text {
            text: Media.player ? Media.player.trackTitle + " — " + Media.player.trackArtist : ""
            color: Config.theme.text
            font.pixelSize: 16
            Layout.maximumWidth: root.width - 160
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }
    onBusyChanged: if (!busy)
                       password.forceActiveFocus()
}
