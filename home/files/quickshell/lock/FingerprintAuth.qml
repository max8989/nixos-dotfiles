pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import ".."
import "FingerprintModel.js" as FingerprintModel

Scope {
    id: root
    property bool enabled: false
    property bool configured: false
    property bool attempting: false
    property bool reachedDevice: false
    property double promptedAt: 0
    property int errors: 0
    property int probeErrors: 0
    readonly property string user: Config.data.user || Quickshell.env("USER")
    readonly property bool unavailable: configured && errors >= 3
    readonly property string message: !configured ? "" : unavailable ? "指紋暫時無法使用，請輸入密碼" : "請掃描指紋解鎖";
    signal authenticated()

    function refresh() {
        if (enabled && !probe.running)
            probe.running = true;
    }
    function stop() {
        attempting = false;
        reachTimeout.stop();
        retry.stop();
        recheck.stop();
        pam.abort();
        probe.running = false;
    }
    function start() {
        if (!enabled || !configured || pam.active || attempting || retry.running)
            return;
        attempting = true;
        reachedDevice = false;
        promptedAt = 0;
        if (pam.start())
            reachTimeout.restart();
        else
            settle(true);
    }
    function settle(deviceError) {
        // PAM errors also emit completed(Error); settle an attempt only once.
        if (!attempting)
            return;
        attempting = false;
        reachTimeout.stop();
        var usable = reachedDevice && !(deviceError && Date.now() - promptedAt < 2000);
        errors = usable ? 0 : Math.min(errors + 1, 7);
        if (enabled && configured) {
            retry.interval = FingerprintModel.retryDelay(errors);
            retry.restart();
        }
    }
    onEnabledChanged: {
        if (enabled) {
            configured = false;
            errors = 0;
            probeErrors = 0;
            refresh();
        } else {
            stop();
            configured = false;
        }
    }
    Connections {
        target: Runtime
        function onResumed() {
            if (!root.enabled)
                return;
            root.stop();
            root.errors = 0;
            // Allow the system's asynchronous fprintd restart to settle.
            retry.interval = 1000;
            retry.restart();
            root.refresh();
        }
    }
    Process {
        id: probe
        command: [Config.bin.fprintdList, root.user]
        stdout: StdioCollector { id: probeOutput; waitForEnd: true }
        stderr: StdioCollector { id: probeError; waitForEnd: true }
        onExited: {
            if (!root.enabled)
                return;
            var state = FingerprintModel.enrollment(probeOutput.text + "\n" + probeError.text);
            if (state === "unknown") {
                root.probeErrors++;
                recheck.interval = FingerprintModel.retryDelay(root.probeErrors);
                recheck.restart();
                return;
            }
            root.probeErrors = 0;
            recheck.stop();
            root.configured = state === "enrolled";
            if (root.configured)
                root.start();
            else
                root.stop();
        }
    }
    Timer {
        id: recheck
        onTriggered: root.refresh()
    }
    Timer {
        id: retry
        onTriggered: root.start()
    }
    Timer {
        id: reachTimeout
        interval: 20000
        onTriggered: {
            pam.abort();
            root.settle(true);
        }
    }
    PamContext {
        id: pam
        config: "quickshell-fingerprint"
        user: root.user
        onPamMessage: {
            // This stack must never ask for a password or receive one.
            if (responseRequired) {
                abort();
                root.settle(true);
            } else if (!messageIsError && !root.reachedDevice) {
                root.reachedDevice = true;
                root.promptedAt = Date.now();
                reachTimeout.stop();
            }
        }
        onCompleted: function(result) {
            if (!root.attempting)
                return;
            if (result === PamResult.Success && root.enabled) {
                root.stop();
                root.authenticated();
            } else
                root.settle(result === PamResult.Error);
        }
    }
}
