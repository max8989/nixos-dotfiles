pragma ComponentBehavior: Bound
import QtQuick
import ".."

Rectangle {
    property string surface: "popups"
    readonly property var style: Config.surface(surface)
    color: Qt.alpha(style.background, style.backgroundAlpha)
    radius: Config.theme.radius
    border.width: style.borderWidth
    border.color: Qt.alpha(style.border, style.borderAlpha)
}
