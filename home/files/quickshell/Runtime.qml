pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string message: ""
    property string menu: ""
    property var menuScreen: null
    property real menuAnchorX: -1
    property bool locked: false
    property bool presentation: false
    property string osdLabel: ""
    property real osdValue: 0
    property bool osdVisible: false
    property bool osdProgress: true
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
        id: messageTimer
        interval: 6000
        onTriggered: root.message = ""
    }
}
