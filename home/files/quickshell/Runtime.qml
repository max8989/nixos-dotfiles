pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string message: ""
    property string menu: ""
    property var menuHistory: []
    property var menuScreen: null
    property real menuAnchorX: -1
    property bool locked: false
    property bool presentation: false
    property string osdLabel: ""
    property real osdValue: 0
    property bool osdVisible: false
    property bool osdProgress: true
    // QML timers run on the monotonic clock, which stops during suspend, so a
    // SystemClock keeps showing the pre-suspend minute after waking. Emitted
    // when wall time jumps past the watchdog interval so clocks can resync.
    signal resumed
    property real lastTick: Date.now()
    function showOsd(label, value) {
        osdLabel = label;
        osdValue = value;
        osdProgress = true;
        osdVisible = true;
        osdTimer.restart();
    }
    function report(text) {
        message = text;
        console.warn(text);
        messageTimer.restart();
        if (!menu && !locked) {
            showOsd(text, 0);
            osdProgress = false;
        }
    }
    function toggleMenu(name, screen, anchorX) {
        if (locked)
            return;
        menuScreen = screen || null;
        menuAnchorX = typeof anchorX === "number" ? anchorX : -1;
        menuHistory = [];
        menu = menu === name ? "" : name;
        message = "";
    }
    function logout() {
        if (Config.preview)
            return;
        run([Config.bin.loginctl, "show-user", Config.data.user, "--property=Display", "--value"], function (
            code, out) {
            if (code || !out.trim()) {
                root.report("No graphical login session found");
                return;
            }
            root.run([Config.bin.loginctl, "terminate-session", out.trim()], function (code) {
                if (code)
                    root.report("Logout failed");
            });
        });
    }
    function closeMenu() {
        menuHistory = [];
        menu = "";
        message = "";
    }
    function launch(args) {
        if (Config.valid && args[0])
            Quickshell.execDetached(args);
    }
    function run(args, callback) {
        if (!Config.valid || !args[0]) {
            if (callback)
                callback(127, "");
            return;
        }
        var job = processFactory.createObject(root, {
                                                  command: args,
                                                  callback: callback || null
                                              });
        job.running = true;
    }
    Component {
        id: processFactory
        Process {
            id: job
            property var callback: null
            stdout: StdioCollector {
                id: output
            }
            // Do not print subprocess stderr: it can contain authentication or
            // clipboard data. Present a contextual error at the call site.
            stderr: StdioCollector {}
            onExited: function (code) {
                if (callback)
                    callback(code, output.text);
                job.destroy();
            }
        }
    }
    Timer {
        id: osdTimer
        interval: 1800
        onTriggered: root.osdVisible = false
    }
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            var now = Date.now();
            if (now - root.lastTick > interval + 10000)
                root.resumed();
            root.lastTick = now;
        }
    }
    Timer {
        id: messageTimer
        interval: 6000
        onTriggered: root.message = ""
    }
}
