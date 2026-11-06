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
    property bool syncing: false
    property bool fresh: false
    property string syncError: ""
    property string syncedAt: ""
    readonly property string countLabel: syncedAt ? String(items.length) + (syncError ? " !" : "") : syncError ? "!" : "…"
    readonly property string status: syncError ? syncError + (syncedAt ? " Showing saved tasks." : "")
        : syncing ? "Syncing TickTick…" : syncedAt ? items.length + " open tasks · updated " + Qt.formatDateTime(new Date(syncedAt), "HH:mm")
        : "TickTick has not synced yet"
    property real now: Date.now()
    readonly property var overdue: Logic.overdue(tasks, now)
    property var notified: []
    property string lastDaily: ""
    property bool stateLoaded: false
    property string phrases: ""
    property string weather: ""
    function refresh() {
        if (Config.preview) {
            snapshotFile.reload();
            return;
        }
        if (syncing)
            return;
        fresh = false;
        syncing = true;
        Runtime.run([Config.bin.ticktick], function (code, out) {
            root.syncing = false;
            var result = Logic.parseJson(out, null);
            if (code) {
                root.syncError = result?.error || "TickTick sync failed. Retry later.";
                return;
            }
            if (!root.acceptSnapshot(result))
                return;
            root.fresh = true;
            snapshotFile.setText(out);
            root.check();
        });
    }
    function acceptSnapshot(result) {
        if (!result || !result.ok || !Array.isArray(result.tasks) || typeof result.syncedAt !== "string" || isNaN(Date.parse(result.syncedAt))) {
            fresh = false;
            syncError = result?.error || "TickTick sync failed. Retry later.";
            return false;
        }
        tasks = result.tasks;
        syncedAt = result.syncedAt;
        syncError = "";
        return true;
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
        if (Config.preview || !fresh || !stateLoaded || Runtime.locked)
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
    function openTask(task) {
        var url = "https://ticktick.com/webapp/";
        if (task)
            url += "#q/all/tasks/" + encodeURIComponent(task.id);
        Runtime.launch([Config.bin.xdgOpen, url]);
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
        id: snapshotFile
        path: Config.preview ? (Config.paths.ticktickFixture || "") : Config.stateDirectory + "/ticktick-tasks.json"
        watchChanges: Config.preview
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (Config.preview || !root.syncedAt)
                root.acceptSnapshot(Logic.parseJson(text(), null));
        }
        onSaveFailed: root.syncError = "TickTick synced, but its saved tasks could not be updated."
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
            if (!Runtime.locked)
                root.refresh();
        }
        function onResumed() { root.refresh(); }
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
        triggeredOnStart: true
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
