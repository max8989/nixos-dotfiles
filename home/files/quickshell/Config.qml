pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Logic.js" as Logic

Singleton {
    id: root
    readonly property bool preview: Quickshell.env("QS_PREVIEW") === "1"
    readonly property bool development: Quickshell.env("QS_DEV") === "1"
    readonly property string stateDirectory: Quickshell.env("QS_STATE_DIR") || ((Quickshell.env(
                                                                                     "XDG_STATE_HOME")
                                                                                 || Quickshell.env("HOME")
                                                                                 + "/.local/state")
                                                                                + "/quickshell-desktop")
    readonly property var data: Logic.parseJson(file.text(), {}) || ({})
    readonly property bool valid: !!(data.theme && data.bin && data.paths && data.features)
    readonly property var theme: data.theme || ({
                                                    text: "#d8f0ff",
                                                    solid: "#0a0a12",
                                                    background: "#b80a0a12",
                                                    surface: "#151c2a",
                                                    accent: "#33ccff",
                                                    blue: "#3366ff",
                                                    dim: "#8998ae",
                                                    success: "#00ff99",
                                                    warning: "#ffcc66",
                                                    urgent: "#ff3366",
                                                    border: "#4d788caa",
                                                    font: "monospace",
                                                    uiFont: "sans-serif",
                                                    fontSize: 14,
                                                    radius: 14
                                                })
    readonly property var bin: data.bin || ({})
    readonly property var paths: data.paths || ({})
    readonly property var bar: data.bar || ({
                                                height: 38,
                                                margin: 6,
                                                sideMargin: 12
                                            })
    readonly property var features: data.features || ({})
    FileView {
        id: file
        path: Quickshell.env("QS_SETTINGS") || Qt.resolvedUrl("generated.json")
        blockLoading: true
        onLoadFailed: console.error("Could not read generated shell settings")
    }
}
