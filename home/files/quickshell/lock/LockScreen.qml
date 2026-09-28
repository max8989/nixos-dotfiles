pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import ".."

Scope {
    id: root
    property bool requested: false
    property string pendingAction: ""
    property string pendingPassword: ""
    property string authMessage: ""
    property bool capturing: false
    property int outstandingCaptures: 0
    property var captures: ({})
    readonly property bool secure: lock.secure
    readonly property string markerPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-lock-" + (
                                             Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "session")
                                         + ".json"
    function request(action) {
        if (Config.preview || !Config.features.lock)
            return;
        Runtime.closeMenu();
        Runtime.locked = true;
        pendingAction = action || "";
        if (requested) {
            performPendingAction();
            return;
        }
        if (capturing)
            return;
        // Record intent before acquiring the lock; a crash must never silently
        // turn a failed authentication into an unlocked session.
        marker.setText("true");
        capturing = true;
        outstandingCaptures = Quickshell.screens.length;
        var images = {};
        Quickshell.screens.forEach(screen => {
            var path = (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell-" + Quickshell.processId
                    + "-" + screen.name.replace(/[^a-zA-Z0-9_-]/g, "_") + ".png";
            images[screen.name] = path;
            Runtime.run([Config.bin.grim, "-o", screen.name, path], function () {
                root.outstandingCaptures--;
                if (root.outstandingCaptures <= 0)
                    root.beginLock();
            });
        });
        captures = images;
        captureDeadline.restart();
        if (!outstandingCaptures)
            beginLock();
    }
    function beginLock() {
        if (!capturing)
            return;
        capturing = false;
        captureDeadline.stop();
        requested = true;
    }
    function submit(password) {
        if (!secure || passwordPam.active)
            return;
        pendingPassword = password;
        authMessage = "";
        if (!passwordPam.start()) {
            pendingPassword = "";
            authMessage = "驗證無法啟動";
        }
    }
    function finishAuthentication() {
        if (!secure)
            return;
        pendingPassword = "";
        passwordPam.abort();
        fingerprintPam.abort();
        marker.setText("false");
        requested = false;
        Runtime.locked = false;
        authMessage = "";
        var paths = Object.values(captures);
        captures = {};
        if (paths.length)
            Runtime.run([Config.bin.remove, "-f", "--"].concat(paths), null);
    }
    function performPendingAction() {
        if (!secure || !pendingAction)
            return;
        var action = pendingAction;
        pendingAction = "";
        if (action === "suspend" || action === "hibernate")
            Runtime.run([Config.bin.systemctl, action], function (code) {
                if (code)
                    root.authMessage = "休眠失敗；請解鎖後重試";
            });
    }
    FileView {
        id: marker
        path: root.markerPath
        printErrors: false
        blockLoading: true
        blockWrites: true
        onLoaded: if (text().trim() === "true" && !Config.preview) {
                      root.requested = true;
                      Runtime.locked = true;
                  }
        onSaveFailed: console.error("Could not save lock recovery marker")
    }
    Timer {
        id: captureDeadline
        interval: 750
        onTriggered: root.beginLock()
    }
    WlSessionLock {
        id: lock
        locked: root.requested
        onSecureStateChanged: {
            if (secure) {
                root.performPendingAction();
                fingerprintPam.start();
            }
        }
        WlSessionLockSurface {
            id: surface
            color: Config.theme.solid
            LockContent {
                anchors.fill: parent
                snapshot: root.captures[surface.screen?.name] ? "file://"
                                                                + root.captures[surface.screen.name] : ""
                authMessage: root.authMessage
                busy: passwordPam.active
                onSubmitted: password => root.submit(password)
            }
        }
    }
    PamContext {
        id: passwordPam
        config: "quickshell"
        onPamMessage: {
            if (responseRequired) {
                respond(root.pendingPassword);
                root.pendingPassword = "";
            } else if (messageIsError)
                root.authMessage = message;
        }
        onCompleted: function (result) {
            root.pendingPassword = "";
            if (result === PamResult.Success)
                root.finishAuthentication();
            else
                root.authMessage = "驗證失敗，請再試一次";
        }
    }
    PamContext {
        id: fingerprintPam
        config: "quickshell-fingerprint"
        onPamMessage: {
            if (responseRequired)
                abort();
        }
        onCompleted: function (result) {
            if (result === PamResult.Success)
                root.finishAuthentication();
        }
    }
    IpcHandler {
        target: "session"
        function lock(): void {
        root.request("");
    }
        function isSecure(): bool {
            return root.secure;
        }
        }
        }
