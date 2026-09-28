pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import ".."

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }
    function change(microphone, delta) {
        var node = microphone ? source : sink;
        setVolume(microphone, (node?.audio?.volume || 0) * 100 + delta);
    }
    function setVolume(microphone, percent) {
        if (Config.preview)
            return;
        var node = microphone ? source : sink;
        if (!node || !node.audio) {
            Runtime.report("No audio device available");
            return;
        }
        node.audio.volume = Math.max(0, Math.min(microphone ? 1 : 1.5, percent / 100));
        Runtime.showOsd(microphone ? "Microphone" : "Volume", node.audio.volume);
    }
    function mute(microphone) {
        if (Config.preview)
            return;
        var node = microphone ? source : sink;
        if (!node || !node.audio)
            return;
        node.audio.muted = !node.audio.muted;
        Runtime.showOsd((microphone ? "Microphone" : "Volume") + (node.audio.muted ? " muted" : " on"),
                        node.audio.muted ? 0 : node.audio.volume);
    }
    function select(node) {
        if (Config.preview)
            return;
        if (node.isSink) {
            Pipewire.preferredDefaultAudioSink = node;
            Preferences.audioSink = node.name;
        } else {
            Pipewire.preferredDefaultAudioSource = node;
            Preferences.audioSource = node.name;
        }
    }
    function restore() {
        if (!Config.preview && Preferences.initialized && Preferences.audioSink) {
            var match = sinks.find(n => n.name === Preferences.audioSink);
            if (match)
                Pipewire.preferredDefaultAudioSink = match;
        }
        if (!Config.preview && Preferences.initialized && Preferences.audioSource) {
            var input = sources.find(n => n.name === Preferences.audioSource);
            if (input)
                Pipewire.preferredDefaultAudioSource = input;
        }
    }
    onSinksChanged: restore()
    onSourcesChanged: restore()
    Connections {
        target: Preferences
        function onInitializedChanged() {
            root.restore();
        }
    }
}
