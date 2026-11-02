pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Singleton {
    id: root
    signal resolved(int id, int pid)
    readonly property bool enabled: Config.valid && Config.features.notifications && !Config.preview
    // Only connection names, call serials, notification IDs and process IDs are retained.
    property var calls: ({})
    onEnabledChanged: monitor.running = enabled
    Component.onCompleted: monitor.running = enabled

    function resolve(key) {
        const call = calls[key];
        if (call && call.id && call.pid) {
            delete calls[key];
            resolved(call.id, call.pid);
        }
    }
    function receive(data) {
        let message;
        try { message = JSON.parse(data); } catch (error) { return; }
        if (message.type === "method_call" && message.member === "Notify"
                && /^:\d+\.\d+$/.test(message.sender) && message.cookie > 0) {
            const now = Date.now();
            Object.keys(calls).forEach(key => { if (now - calls[key].time > 10000) delete calls[key]; });
            if (Object.keys(calls).length >= 128)
                delete calls[Object.keys(calls)[0]];
            const key = message.sender + ":" + message.cookie;
            calls[key] = {id: 0, pid: 0, time: now};
            Runtime.run([Config.bin.busctl, "--user", "--json=short", "call", "org.freedesktop.DBus",
                "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", message.sender],
                function(code, output) {
                    if (!root.calls[key]) return;
                    let pid = 0;
                    try { pid = JSON.parse(output).data[0]; } catch (error) {}
                    if (code || !Number.isSafeInteger(pid) || pid <= 0) {
                        delete root.calls[key];
                        return;
                    }
                    root.calls[key].pid = pid;
                    root.resolve(key);
                });
        } else if (message.type === "method_return" || message.type === "error") {
            const key = message.destination + ":" + message.reply_cookie;
            if (!calls[key]) return;
            const id = message.payload?.data?.[0];
            if (message.type === "error" || !Number.isSafeInteger(id) || id <= 0) {
                delete calls[key];
                return;
            }
            calls[key].id = id;
            resolve(key);
        }
    }
    Process {
        id: monitor
        command: [Config.bin.busctl, "--user", "--json=short",
            "--match=type='method_call',destination='org.freedesktop.Notifications',interface='org.freedesktop.Notifications',member='Notify'",
            "--match=type='method_return',sender='org.freedesktop.Notifications'",
            "--match=type='error',sender='org.freedesktop.Notifications'", "monitor"]
        stdout: SplitParser { onRead: data => root.receive(data) }
        stderr: StdioCollector {}
        onExited: {
            root.calls = ({});
            if (root.enabled) {
                console.warn("Notification sender tracking disconnected; reconnecting");
                reconnect.restart();
            }
        }
    }
    Timer {
        id: reconnect
        interval: 2000
        onTriggered: { if (root.enabled) monitor.running = true; }
    }
}
