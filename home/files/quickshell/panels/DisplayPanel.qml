pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."
import "../services"
import "../widgets"

SettingsScroll {
    id: root
    property var display: Display
    property var monitorModel: display.monitors
    property string selectedMonitor: ""
    readonly property var monitor: monitorModel.find(m => m.name === selectedMonitor)
        || monitorModel.find(m => m.focused) || monitorModel[0] || null
    function focusDefault() {
        if (display.scaleBusy) revert.forceActiveFocus(Qt.TabFocusReason);
        else if (brightness.enabled) brightness.focusDefault();
        else textSize.focusDefault();
    }
    Connections {
        target: root.display
        function onScaleSecondsChanged() {
            if (root.display.scaleSeconds === 15) revert.forceActiveFocus(Qt.TabFocusReason);
        }
        function onScaleBusyChanged() {
            if (!root.display.scaleBusy && root.visible) scaleFocusDelay.restart();
        }
    }
    Timer { id: scaleFocusDelay; interval: 60; onTriggered: if (root.visible) root.focusDefault() }
    ColumnLayout {
        visible: root.display.scaleBusy
        Layout.fillWidth: true
        SettingsText { text: "Keep this scale? Reverting in " + root.display.scaleSeconds + " seconds."; Layout.fillWidth: true; color: Config.theme.warning }
        RowLayout {
            SettingsButton { id: revert; objectName: "revertScale"; text: "Revert"; onClicked: root.display.revertScale() }
            SettingsButton { objectName: "keepScale"; text: "Keep scale"; enabled: root.display.scaleSeconds > 0; onClicked: root.display.keepScale() }
        }
    }
    SettingsSlider {
        id: brightness
        objectName: "displayBrightness"
        Layout.fillWidth: true
        title: "Laptop brightness"
        readout: root.display.brightnessPercent < 0 ? "Unavailable" : Math.round(value) + "%"
        from: 1
        value: Math.max(1, root.display.brightnessPercent)
        enabled: root.display.brightnessPercent >= 0 && !root.display.scaleBusy
        onMoved: value => root.display.setBrightness(value)
    }
    SettingsSlider {
        id: textSize
        objectName: "panelTextSize"
        Layout.fillWidth: true
        title: "Panel text size"
        readout: Math.round(value) + " px"
        from: 12
        to: 20
        stepSize: 1
        value: Preferences.panelTextSize
        enabled: !root.display.scaleBusy
        onMoved: value => Preferences.panelTextSize = Math.round(value)
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Config.theme.border }
    SettingsText { text: "DISPLAYS"; caption: true }
    Repeater {
        model: root.monitorModel
        SettingsButton {
            required property var modelData
            Layout.fillWidth: true
            text: modelData.name + (modelData.focused ? " · focused" : "")
            detail: modelData.description + " · " + modelData.width + " × " + modelData.height
            selected: modelData === root.monitor
            enabled: !root.display.scaleBusy
            onClicked: root.selectedMonitor = modelData.name
        }
    }
    SettingsText { visible: !root.monitor; text: "Display configuration is available in a Hyprland session."; Layout.fillWidth: true }
    SettingsText {
        visible: !!root.monitor
        text: "SCALE · " + (root.monitor?.scale || 1) + "×"
        caption: true
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.display.scalesFor(root.monitor)
            SettingsButton {
                required property real modelData
                text: modelData + "×"
                selected: Math.abs((root.monitor?.scale || 1) - modelData) < 0.01
                enabled: !root.display.scaleBusy && !root.display.restoringScales
                onClicked: root.display.previewScale(root.monitor, modelData)
            }
        }
    }
    SettingsText {
        visible: !!root.monitor
        Layout.fillWidth: true
        caption: true
        text: "Scale changes the size of all apps. Confirm within 15 seconds to save it for this display."
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Config.theme.border }
    SettingsButton {
        text: Preferences.nightlight ? "Night light · on" : "Night light · off"
        Layout.fillWidth: true
        selected: Preferences.nightlight
        enabled: !root.display.scaleBusy
        onClicked: root.display.toggleNightlight()
    }
    SettingsSlider {
        Layout.fillWidth: true
        visible: Preferences.nightlight
        title: "Colour temperature"
        readout: Math.round(value) + " K"
        from: 2500
        to: 6000
        stepSize: 250
        value: Preferences.temperature
        enabled: !root.display.scaleBusy
        onMoved: value => root.display.applyNightlight(true, Math.round(value))
    }
    SettingsButton {
        text: Runtime.presentation ? "Keep awake · on" : "Keep awake · off"
        detail: "Prevent automatic screen blanking and sleep"
        Layout.fillWidth: true
        selected: Runtime.presentation
        enabled: !root.display.scaleBusy
        onClicked: Runtime.presentation = !Runtime.presentation
    }
}
