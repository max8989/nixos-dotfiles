pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import ".."
import "../services"

Item {
    id: root
    property string snapshot: ""
    property string authMessage: ""
    property bool busy: false
    signal submitted(string password)

    readonly property bool compact: height < 700
    readonly property int inset: width < 700 ? 24 : 48
    readonly property color ink: Config.theme.text
    readonly property color muted: Config.theme.dim
    readonly property color jade: Config.theme.accent
    readonly property string phrase: {
        var lines = Reminders.phrases.trim().split("\n").filter(line => line.trim().length > 0);
        var day = Math.floor((clock.date - new Date(clock.date.getFullYear(), 0, 0)) / 86400000);
        return lines.length ? lines[day % lines.length] : "";
    }
    function submit() {
        if (busy)
            return;
        root.submitted(password.text);
        password.text = "";
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // A self-contained landscape also covers startup and missing snapshots.
    // Only repaint on resize; the resting lock screen has no animation loop.
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var sky = ctx.createLinearGradient(0, 0, width, height);
            sky.addColorStop(0, "#0c191e");
            sky.addColorStop(0.55, "#19342f");
            sky.addColorStop(1, "#30473d");
            ctx.fillStyle = sky;
            ctx.fillRect(0, 0, width, height);
            var glow = ctx.createRadialGradient(width * 0.74, height * 0.27, 0, width * 0.74, height * 0.27, width * 0.55);
            glow.addColorStop(0, "#405c4c");
            glow.addColorStop(1, "transparent");
            ctx.fillStyle = glow;
            ctx.fillRect(0, 0, width, height);
            // Quiet, overlapping silhouettes inspired by ink landscapes.
            ctx.fillStyle = "#29463e";
            ctx.beginPath();
            ctx.moveTo(0, height * 0.68);
            ctx.bezierCurveTo(width * 0.20, height * 0.82, width * 0.30, height * 0.43, width * 0.53, height * 0.63);
            ctx.bezierCurveTo(width * 0.73, height * 0.82, width * 0.86, height * 0.35, width, height * 0.48);
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#1b3632";
            ctx.beginPath();
            ctx.moveTo(0, height * 0.60);
            ctx.bezierCurveTo(width * 0.22, height * 0.43, width * 0.32, height * 0.88, width * 0.58, height * 0.77);
            ctx.bezierCurveTo(width * 0.80, height * 0.66, width * 0.89, height * 0.77, width, height * 0.64);
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fill();
            ctx.fillStyle = "#102824";
            ctx.beginPath();
            ctx.moveTo(0, height * 0.86);
            ctx.bezierCurveTo(width * 0.25, height * 0.95, width * 0.36, height * 0.71, width * 0.61, height * 0.85);
            ctx.bezierCurveTo(width * 0.80, height * 0.98, width * 0.90, height * 0.80, width, height * 0.84);
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fill();
        }
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
        visible: backdrop.status === Image.Ready
        blurEnabled: true
        blurMax: 64
        blur: 1
        saturation: -1
        opacity: 0.06
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#10060f13"
            }
            GradientStop {
                position: 0.6
                color: "#00060f13"
            }
            GradientStop {
                position: 1
                color: "#70060f13"
            }
        }
    }

    Row {
        anchors {
            left: parent.left
            top: parent.top
            margins: root.inset
        }
        spacing: 10
        Text {
            text: "\uf023"
            font.family: Config.theme.font
            font.pixelSize: 14
            color: root.jade
        }
        Text {
            text: "已鎖定"
            font.family: Config.theme.uiFont
            font.pixelSize: 13
            font.letterSpacing: 2
            color: root.muted
        }
    }
    Row {
        anchors {
            right: parent.right
            top: parent.top
            margins: root.inset
        }
        spacing: 24
        Text {
            text: Reminders.weather.replace(/^天氣:\s*/, "")
            visible: root.width > 650 && text.length > 0
            color: root.muted
            font.family: Config.theme.uiFont
            font.pixelSize: 14
            textFormat: Text.PlainText
        }
        Row {
            spacing: 9
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 11
                radius: 3
                color: "transparent"
                border.color: root.muted
                Rectangle {
                    x: 3
                    y: 3
                    width: 16 * (Battery.present ? Battery.percent / 100 : 1)
                    height: 5
                    radius: 1
                    color: Battery.present && Battery.percent < 20 ? "#e6b68d" : root.jade
                }
                Rectangle {
                    x: 23
                    y: 4
                    width: 2
                    height: 3
                    radius: 1
                    color: root.muted
                }
            }
            Text {
                text: Battery.present ? Battery.percent + "%" : "AC"
                color: root.muted
                font.family: Config.theme.uiFont
                font.pixelSize: 14
            }
        }
    }

    Column {
        id: center
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(78, (root.height - height) * 0.40)
        width: Math.min(340, root.width - 48)
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: root.ink
            font.family: Config.theme.uiFont
            font.pixelSize: root.compact ? 88 : 120
            font.weight: Font.Light
            font.letterSpacing: -4
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "M月d日") + "  ·  " + ["星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"][clock.date.getDay()]
            color: root.muted
            font.family: Config.theme.uiFont
            font.pixelSize: 16
            font.letterSpacing: 2
        }
        Item {
            width: 1
            height: root.compact ? 32 : 60
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: Config.data.user || "歡迎回來"
            color: root.ink
            font.family: Config.theme.uiFont
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        Item {
            width: 1
            height: 16
        }
        TextField {
            id: password
            objectName: "lockPassword"
            width: parent.width
            height: 54
            enabled: !root.busy
            focus: true
            echoMode: TextInput.Password
            passwordCharacter: "•"
            placeholderText: "輸入密碼"
            placeholderTextColor: root.muted
            color: root.ink
            selectionColor: root.jade
            selectedTextColor: "#102824"
            font.family: Config.theme.uiFont
            font.pixelSize: 16
            leftPadding: 20
            rightPadding: 62
            verticalAlignment: TextInput.AlignVCenter
            Accessible.name: "密碼"
            background: Rectangle {
                radius: 27
                color: password.activeFocus ? "#b31a302d" : "#99142624"
                border.width: 1
                border.color: root.authMessage ? "#d7a497" : password.activeFocus ? "#88b8d9c5" : "#405d7369"
                Behavior on border.color {
                    ColorAnimation {
                        duration: 160
                    }
                }
            }
            onAccepted: root.submit()
            Keys.onEscapePressed: text = ""
            Component.onCompleted: forceActiveFocus()
            Button {
                id: unlock
                objectName: "lockSubmit"
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 7
                }
                width: 40
                height: 40
                enabled: !root.busy
                hoverEnabled: true
                focusPolicy: Qt.TabFocus
                Accessible.name: "解鎖"
                contentItem: Text {
                    text: root.busy ? "…" : "→"
                    color: "#19342b"
                    font.family: Config.theme.uiFont
                    font.pixelSize: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 20
                    color: unlock.down ? "#91bba2" : unlock.hovered ? "#d8ecdf" : root.jade
                    border.width: unlock.visualFocus ? 2 : 0
                    border.color: root.ink
                }
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                onClicked: root.submit()
            }
        }
        Item {
            width: 1
            height: 14
        }
        Text {
            width: parent.width
            text: root.busy ? "正在驗證…" : root.authMessage || "按 Enter 解鎖"
            color: root.authMessage && !root.busy ? "#efb9ab" : root.muted
            font.family: Config.theme.uiFont
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
        }
    }

    Column {
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: root.inset
        }
        width: Math.min(360, root.width * 0.36)
        spacing: 12
        visible: !root.compact && root.width > 700 && root.phrase.length > 0
        Rectangle {
            width: 28
            height: 2
            color: root.jade
            opacity: 0.6
        }
        Text {
            width: parent.width
            text: root.phrase
            color: root.jade
            font.family: Config.theme.uiFont
            font.pixelSize: 22
            font.letterSpacing: 4
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
        Text {
            text: "每天一點進步"
            color: root.muted
            font.family: Config.theme.uiFont
            font.pixelSize: 12
            font.letterSpacing: 2
        }
    }
    Column {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: root.inset
        }
        width: Math.min(280, root.width * 0.25)
        spacing: 12
        visible: !root.compact && root.width > 1000 && Reminders.items.length > 0
        Text {
            text: "待辦事項  ·  " + Reminders.items.length
            color: root.muted
            font.family: Config.theme.uiFont
            font.pixelSize: 12
            font.letterSpacing: 2
        }
        Repeater {
            model: Reminders.items.slice(0, 3)
            RowLayout {
                required property string modelData
                width: parent.width
                spacing: 10
                Rectangle {
                    implicitWidth: 4
                    implicitHeight: 4
                    radius: 2
                    color: root.jade
                    opacity: 0.65
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData
                    color: root.jade
                    font.family: Config.theme.uiFont
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
        }
    }
    Text {
        anchors {
            bottom: parent.bottom
            bottomMargin: root.inset
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.min(340, root.width - 48)
        visible: !!Media.player && !root.compact
        text: Media.player ? "♫  " + Media.player.trackTitle + " — " + Media.player.trackArtist : ""
        color: root.muted
        font.family: Config.theme.uiFont
        font.pixelSize: 13
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
    }
    onBusyChanged: if (!busy)
        password.forceActiveFocus()
}
