pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."
import "WindowActivity.js" as Activity

Singleton {
    id: root
    property var entries: []
    readonly property var popups: entries.filter(e => e.popup && !Preferences.dnd && !Runtime.locked)
    function snapshot(n) {
        var target = WindowActivity.target({app: n.appName, desktopEntry: n.desktopEntry});
        return {
            id: n.id,
            notification: n,
            title: n.summary,
            body: n.body,
            app: n.appName,
            desktopEntry: n.desktopEntry,
            windowAddress: target?.address || "",
            unread: Runtime.locked || !target || target.address !== WindowActivity.activeAddress,
            image: n.image,
            time: Date.now(),
            popup: !Preferences.dnd && !Runtime.locked,
            timeout: n.expireTimeout < 0 ? (n.urgency === NotificationUrgency.Critical ? 0 : 5000) :
                                           n.expireTimeout
        };
    }
    function archive(entry) {
        var n = entry.notification;
        return Object.assign({}, entry, {
            notification: null,
            title: n ? n.summary : entry.title,
            body: n ? n.body : entry.body,
            image: n ? n.image : entry.image,
            popup: false
        });
    }
    function receive(n) {
        n.tracked = true;
        n.closed.connect(function () {
            root.entries = root.entries.map(e => e.id === n.id && e.notification === n ? root.archive(e) : e);
        });
        var next = entries.filter(e => e.id !== n.id);
        next.unshift(snapshot(n));
        if (next.length > 100) {
            var removed = next.pop();
            if (removed.notification)
                removed.notification.dismiss();
        }
        entries = next;
    }
    function dismiss(id) {
        var entry = entries.find(e => e.id === id);
        entries = entries.filter(e => e.id !== id);
        if (entry && entry.notification)
            entry.notification.dismiss();
    }
    function clear() {
        var old = entries;
        entries = [];
        old.forEach(e => {
            if (e.notification)
                e.notification.dismiss();
        });
    }
    function invoke(id, action) {
        var entry = entries.find(e => e.id === id);
        if (!entry || !entry.notification)
            return;
        var resident = entry.notification.resident;
        Runtime.closeMenu();
        read(id);
        action.invoke();
        if (!resident)
            dismiss(id);
    }
    function read(id) {
        entries = entries.map(e => e.id === id ? Object.assign({}, e, {unread: false, popup: false}) : e);
    }
    function readActive() {
        var address = WindowActivity.activeAddress;
        if (Runtime.locked || !address)
            return;
        if (entries.some(e => e.unread && WindowActivity.target(e)?.address === address)) {
            entries = entries.map(e => e.unread && WindowActivity.target(e)?.address === address
                                  ? Object.assign({}, e, {unread: false}) : e);
        }
    }
    function canActivate(entry) {
        return !!Activity.defaultAction(entry.notification?.actions) || !!WindowActivity.target(entry);
    }
    function activate(id) {
        if (Runtime.locked)
            return;
        var entry = entries.find(e => e.id === id);
        if (!entry)
            return;
        var action = Activity.defaultAction(entry.notification?.actions);
        if (action) {
            invoke(id, action);
        } else if (WindowActivity.focus(WindowActivity.target(entry))) {
            read(id);
        } else {
            Runtime.report("This notification has no open window");
        }
    }
    Connections {
        target: WindowActivity
        function onActiveAddressChanged() {
            root.readActive();
        }
    }
    Connections {
        target: Runtime
        function onLockedChanged() {
            root.readActive();
        }
    }
    IpcHandler {
        target: "notifications"
        function count(): int {
            return root.entries.length;
        }
        function popupCount(): int {
            return root.popups.length;
        }
        function toggleDnd(): void {
        Preferences.dnd = !Preferences.dnd;
    }
        function clear(): void {
                              root.clear();
                          }
    }
    LazyLoader {
        active: Config.valid && Config.features.notifications && !Config.preview
        NotificationServer {
            persistenceSupported: true
            actionsSupported: true
            imageSupported: true
            bodyMarkupSupported: false
            onNotification: function (notification) {
                root.receive(notification);
            }
        }
    }
    Timer {
        interval: 250
        running: root.entries.some(e => e.notification && e.timeout > 0)
        repeat: true
        onTriggered: {
            var expired = [];
            var next = root.entries.map(e => {
                if (e.notification && e.timeout > 0 && Date.now() - e.time >= e.timeout) {
                    var copy = root.archive(e);
                    expired.push(e.notification);
                    return copy;
                }
                return e;
            });
            if (expired.length) {
                root.entries = next;
                expired.forEach(n => n.expire());
            }
        }
    }
}
