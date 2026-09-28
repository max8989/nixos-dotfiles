pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import ".."
import "../services"
import "../widgets"

SettingsScroll {
    id: root
    property var audio: Audio
    property bool testingMicrophone: false
    function focusDefault() { if (output.enabled) output.focusDefault(); else outputMute.forceActiveFocus(Qt.TabFocusReason); }
    onVisibleChanged: if (!visible) testingMicrophone = false
    PwNodePeakMonitor {
        id: meter
        node: root.audio === Audio ? Audio.source : null
        enabled: root.visible && root.testingMicrophone && !Config.preview
    }
    SettingsText { text: "SPEAKERS & HEADPHONES"; caption: true }
    SettingsSlider {
        id: output
        objectName: "outputVolume"
        Layout.fillWidth: true
        title: "Output volume"
        readout: root.audio.sink?.audio ? Math.round(value) + "%" : "Unavailable"
        enabled: !!root.audio.sink?.audio
        value: (root.audio.sink?.audio?.volume || 0) * 100
        to: 150
        onMoved: value => root.audio.setVolume(false, value)
    }
    SettingsButton {
        id: outputMute
        Layout.fillWidth: true
        text: root.audio.sink?.audio?.muted ? "Unmute speakers" : "Mute speakers"
        enabled: !!root.audio.sink?.audio
        selected: !!root.audio.sink?.audio?.muted
        onClicked: root.audio.mute(false)
    }
    Repeater {
        model: root.audio.sinks
        SettingsButton {
            required property var modelData
            Layout.fillWidth: true
            text: (selected ? "✓  " : "") + modelData.description
            selected: modelData === root.audio.sink
            onClicked: root.audio.select(modelData)
        }
    }
    SettingsText { visible: root.audio.sinks.length === 0; text: "No output devices connected." }
    Rectangle { Layout.fillWidth: true; height: 1; color: Config.theme.border }
    SettingsText { text: "MICROPHONE"; caption: true }
    SettingsSlider {
        objectName: "inputVolume"
        Layout.fillWidth: true
        title: "Input volume"
        readout: root.audio.source?.audio ? Math.round(value) + "%" : "Unavailable"
        enabled: !!root.audio.source?.audio
        value: (root.audio.source?.audio?.volume || 0) * 100
        onMoved: value => root.audio.setVolume(true, value)
    }
    RowLayout {
        Layout.fillWidth: true
        SettingsButton {
            Layout.fillWidth: true
            text: root.audio.source?.audio?.muted ? "Unmute microphone" : "Mute microphone"
            enabled: !!root.audio.source?.audio
            selected: !!root.audio.source?.audio?.muted
            onClicked: root.audio.mute(true)
        }
        SettingsButton {
            text: root.testingMicrophone ? "Stop test" : "Test mic"
            enabled: !!root.audio.source?.audio
            selected: root.testingMicrophone
            onClicked: root.testingMicrophone = !root.testingMicrophone
        }
    }
    Rectangle {
        visible: root.testingMicrophone
        Layout.fillWidth: true
        height: 6
        radius: 3
        color: Config.theme.surface
        Rectangle { width: parent.width * Math.min(1, meter.peak); height: 6; radius: 3; color: Config.theme.success }
    }
    SettingsText { visible: root.testingMicrophone; text: "Live input level · audio is not saved"; caption: true }
    Repeater {
        model: root.audio.sources
        SettingsButton {
            required property var modelData
            Layout.fillWidth: true
            text: (selected ? "✓  " : "") + modelData.description
            selected: modelData === root.audio.source
            onClicked: root.audio.select(modelData)
        }
    }
    SettingsText { visible: root.audio.sources.length === 0; text: "No microphones connected." }
}
