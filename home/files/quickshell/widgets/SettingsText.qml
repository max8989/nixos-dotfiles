pragma ComponentBehavior: Bound
import QtQuick
import ".."

Text {
    property bool caption: false
    color: caption ? Config.theme.dim : Config.theme.text
    font.family: Config.theme.uiFont
    font.pixelSize: Preferences.panelTextSize + (caption ? -2 : 0)
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
}
