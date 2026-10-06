pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Logic.js" as Logic

Singleton {
    id: root
    property var tasks: []
    readonly property var items: tasks.map(t => t.label ? t.text + "  · " + t.label : t.text)
    property real now: Date.now()
    readonly property var overdue: Logic.overdue(tasks, now)
    property var notified: []
    property string lastDaily: ""
    property bool stateLoaded: false
    property string phrases: ""
    property string weather: ""
    function refresh() {
        todoFile.reload();
    }
    function isOverdue(task) {
        return task.due !== null && task.due <= now;
    }
    function notify(title, body) {
        Runtime.run([Config.bin.notifySend, "-a", "Reminders", "-u", "critical", title, body]);
    }
    // Notify once per task when it becomes past due, plus one summary on the
    // first unlocked moment of each day. Runs on load, unlock and every minute.
    function check() {
        now = Date.now();
        if (Config.preview || !stateLoaded || Runtime.locked)
            return;
        var keys = overdue.map(Logic.taskKey);
        var seen = notified.filter(k => keys.indexOf(k) >= 0);
        var changed = seen.length !== notified.length;
        var today = Logic.dayKey(new Date(now));
        if (lastDaily !== today && overdue.length > 0) {
            notify(overdue.length + (overdue.length === 1 ? " overdue task" : " overdue tasks"),
                   overdue.map(t => "• " + t.text + " (" + t.label + ")").join("\n"));
            lastDaily = today;
            seen = keys;
            changed = true;
        }
        overdue.forEach(t => {
            var key = Logic.taskKey(t);
            if (seen.indexOf(key) < 0) {
                root.notify("Past due", t.text + " (" + t.label + ")");
                seen.push(key);
                changed = true;
            }
        });
        if (changed) {
            notified = seen;
            stateFile.setText(JSON.stringify({ notified: notified, lastDaily: lastDaily }));
        }
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
        onLoaded: {
            root.tasks = Logic.tasks(text());
            root.check();
        }
        onLoadFailed: root.tasks = []
    }
    FileView {
        id: stateFile
        path: Config.stateDirectory + "/reminders.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            if (root.stateLoaded)
                return;
            var state = Logic.parseJson(text(), {});
            root.notified = Array.isArray(state.notified) ? state.notified : [];
            root.lastDaily = typeof state.lastDaily === "string" ? state.lastDaily : "";
            root.stateLoaded = true;
            root.check();
        }
        onLoadFailed: {
            root.stateLoaded = true;
            root.check();
        }
        onSaveFailed: console.warn("Reminder state could not be saved")
    }
    Connections {
        target: Runtime
        function onLockedChanged() {
            root.check();
        }
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
        onTriggered: {
            root.refresh();
            root.check();
        }
    }
    Timer {
        interval: 900000
        running: !Config.preview
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }
}
