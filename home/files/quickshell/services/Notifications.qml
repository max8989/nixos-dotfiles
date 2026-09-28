pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."

Singleton {
    id: root
    property var entries: []
    readonly property var popups: entries.filter(e => e.popup && !Preferences.dnd && !Runtime.locked)
    function snapshot(n) {
        return {
            id: n.id,
            notification: n,
            title: n.summary,
            body: n.body,
            app: n.appName,
            image: n.image,
            time: Date.now(),
            popup: !Preferences.dnd && !Runtime.locked,
            timeout: n.expireTimeout < 0 ? (n.urgency === NotificationUrgency.Critical ? 0 : 5000) :
                                           n.expireTimeout
        };
    }
    function receive(n) {
        n.tracked = true;
        n.closed.connect(function () {
            root.entries = root.entries.map(e => e.id === n.id && e.notification ? {
                                                                                       id: e.id,
                                                                                       notification: null,
                                                                                       title: n.summary,
                                                                                       body: n.body,
                                                                                       app: n.appName,
                                                                                       image: n.image,
                                                                                       time: e.time,
                                                                                       popup: false,
                                                                                       timeout: e.timeout
                                                                                   } : e);
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
        action.invoke();
        if (!resident)
            dismiss(id);
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
                    var copy = {
                        id: e.id,
                        notification: null,
                        title: e.notification.summary,
                        body: e.notification.body,
                        app: e.notification.appName,
                        image: e.notification.image,
                        time: e.time,
                        popup: false,
                        timeout: e.timeout
                    };
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
