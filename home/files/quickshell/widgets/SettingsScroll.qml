pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root
    default property alias body: column.data
    readonly property real bodyHeight: column.implicitHeight
    clip: true
    rightPadding: 12
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    ColumnLayout {
        id: column
        width: root.availableWidth
        spacing: 16
    }
    function reveal(item) {
        if (!item || !root.visible)
            return;
        var ancestor = item;
        while (ancestor && ancestor !== column)
            ancestor = ancestor.parent;
        if (!ancestor)
            return;
        var view = root.contentItem as Flickable;
        if (!view)
            return;
        var y = item.mapToItem(column, 0, 0).y;
        if (y < view.contentY)
            view.contentY = y;
        else if (y + item.height > view.contentY + view.height)
            view.contentY = y + item.height - view.height;
    }
    Connections {
        target: root.Window.window
        function onActiveFocusItemChanged() { root.reveal(root.Window.window?.activeFocusItem); }
    }
}
