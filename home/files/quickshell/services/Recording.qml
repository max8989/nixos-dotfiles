pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    property var state: ({active: false})
    property string audioMode: "none"
    property double now: Date.now()
    readonly property bool active: state.active === true
    readonly property var audioModes: ["none", "desktop", "microphone"]
    readonly property var audioLabels: ({none: "No audio", desktop: "Desktop audio", microphone: "Microphone"})
    readonly property string audioLabel: audioLabels[audioMode]
    readonly property int elapsed: state.startedAt ? Math.max(0, Math.floor(now / 1000 - state.startedAt)) : 0
    readonly property string label: state.phase === "selecting" ? "Select area"
                                    : state.phase === "countdown" ? "Starting…"
                                    : state.phase === "stopping" ? "Saving…"
                                    : Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")
    readonly property string detail: (state.mode === "windows" ? "Window" : state.mode === "region" ? "Region" : "Monitor")
                                     + " · " + (audioLabels[state.audio] || "No audio")
    function cycleAudio(direction) {
        audioMode = audioModes[(audioModes.indexOf(audioMode) + direction + audioModes.length) % audioModes.length];
    }
    function stop() {
        if (Config.preview) return;
        Runtime.run([Config.paths.screenRecord, "--stop"], function(code) {
            if (code) Runtime.report("Screen recording could not be stopped");
            root.refresh();
        });
    }
    function refresh() {
        if (!Config.preview && !status.running)
            status.running = true;
    }
    Process {
        id: status
        command: [Config.paths.screenRecord, "--status"]
        running: !Config.preview
        stdout: StdioCollector {
            onStreamFinished: root.state = Logic.parseJson(this.text, {active: false})
        }
        onExited: code => { if (code) root.state = {active: false}; }
    }
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now();
            root.refresh();
        }
    }
}
