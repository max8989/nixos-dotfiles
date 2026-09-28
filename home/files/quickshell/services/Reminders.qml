pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    property var items: []
    property string phrases: ""
    property string weather: ""
    function refresh() {
        todoFile.reload();
    }
    function openNote(note) {
        Runtime.launch([Config.bin.xdgOpen, "obsidian://open?vault=" + encodeURIComponent(Config.paths.vault)
                        + "&file=" + encodeURIComponent(note)]);
    }
    function fetchWeather() {
        if (Config.preview)
            return;
        Runtime.run([Config.bin.curl, "-fsS", "--max-time", "3", "https://wttr.in/?format=%C+%t&lang=zh-tw"],
                    function (code, out) {
                        if (!code && out.trim() && out.length < 160 && !/unknown|error|sorry|</i.test(out)) {
                            root.weather = "天氣: " + out.trim().replace(/\+/g, " ");
                            cache.setText(root.weather);
                        }
                    });
    }
    FileView {
        id: todoFile
        path: Config.paths.todo || ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.items = Logic.todos(text())
        onLoadFailed: root.items = []
    }
    FileView {
        path: Config.paths.phrases || ""
        onLoaded: root.phrases = text()
    }
    FileView {
        id: cache
        path: Config.stateDirectory + "/weather.txt"
        printErrors: false
        onLoaded: root.weather = text()
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 900000
        running: !Config.preview
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }
}
