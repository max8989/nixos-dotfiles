pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Singleton {
    id: root
    property bool initialized: false
    property bool nightlight: false
    property int temperature: 4000
    property bool dnd: false
    property bool barHidden: false
    property string audioSink: ""
    property string audioSource: ""
    property int panelTextSize: Config.fonts.body
    property var monitorScales: ({})
    property var appLaunchCounts: Object.create(null)
    property string folder: ""
    function recordAppLaunch(id) {
        var counts = Object.assign(Object.create(null), appLaunchCounts);
        counts[id] = Math.min(Number.MAX_SAFE_INTEGER, (counts[id] || 0) + 1);
        appLaunchCounts = counts;
    }
    function save() {
        if (initialized)
            saveTimer.restart();
    }
    onNightlightChanged: save()
    onTemperatureChanged: save()
    onDndChanged: save()
    onBarHiddenChanged: save()
    onAudioSinkChanged: save()
    onAudioSourceChanged: save()
    onPanelTextSizeChanged: save()
    onMonitorScalesChanged: save()
    onAppLaunchCountsChanged: save()
    onFolderChanged: save()
    FileView {
        id: file
        path: Config.stateDirectory + "/state.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.initialized)
                return;
            var state = Logic.restoreState(Logic.parseJson(text(), {}));
            root.nightlight = state.nightlight;
            root.temperature = state.temperature;
            root.dnd = state.dnd;
            root.barHidden = state.barHidden;
            root.audioSink = state.audioSink;
            root.audioSource = state.audioSource;
            root.panelTextSize = state.panelTextSize;
            root.monitorScales = state.monitorScales;
            root.appLaunchCounts = state.appLaunchCounts;
            root.folder = state.folder;
            root.initialized = true;
        }
        onLoadFailed: root.initialized = true
        onSaveFailed: console.warn("Shell preferences could not be saved")
    }
    Timer {
        id: saveTimer
        interval: 250
        onTriggered: file.setText(JSON.stringify({
            nightlight: root.nightlight,
            temperature: root.temperature,
            dnd: root.dnd,
            barHidden: root.barHidden,
            audioSink: root.audioSink,
            audioSource: root.audioSource,
            panelTextSize: root.panelTextSize,
            monitorScales: root.monitorScales,
            appLaunchCounts: root.appLaunchCounts,
            folder: root.folder
        }))
    }
}
