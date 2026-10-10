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
    readonly property string stateDirectory: Quickshell.env("QS_STATE_DIR") || ((Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell-desktop")
    readonly property var data: Logic.parseJson(file.text(), {}) || ({})
    readonly property bool valid: !!(data.theme && data.bin && data.paths && data.features)
    property string selectedTheme: "tokyo-night"
    readonly property var theme: data.themes?.[selectedTheme] || data.theme || ({
            text: "#a9b1d6",
            solid: "#1a1b26",
            background: "#1a1b26",
            surface: "#24283b",
            accent: "#7aa2f7",
            blue: "#7aa2f7",
            dim: "#b4bee6",
            success: "#9ece6a",
            warning: "#eb927b",
            urgent: "#f7768e",
            border: "#7aa2f7",
            font: "monospace",
            uiFont: "sans-serif",
            fontSize: 12,
            radius: 12
        })
    readonly property var bin: data.bin || ({})
    readonly property var paths: data.paths || ({})
    readonly property var bar: data.bar || ({
            height: 38,
            margin: 6,
            sideMargin: 12,
            fontSize: 14
        })
    readonly property var fonts: theme.fonts || ({
            caption: 10,
            bodySmall: 11,
            body: 12,
            subtitle: 13,
            title: 14,
            heading: 16,
            display: 24,
            displayLarge: 28,
            iconSmall: 11,
            icon: 14,
            iconLarge: 18
        })
    readonly property var spacing: theme.spacing || ({
            controlGap: 8,
            controlPaddingX: 10,
            controlPaddingY: 6,
            controlHeight: 28,
            popupRowHeight: 28,
            rowGap: 8,
            rowPaddingX: 12,
            panelGap: 14,
            panelPadding: 18,
            popupPadding: 14
        })
    readonly property var controls: theme.controls || ({
            normalFillAlpha: 0.04,
            normalBorderAlpha: 0.4,
            hoverFillAlpha: 0.08,
            hoverBorderAlpha: 0.25,
            selectedFillAlpha: 0.18,
            pressedFillAlpha: 0.22,
            selectionFillAlpha: 0.35
        })
    function surface(name) {
        return theme.surfaces?.[name] || {
            background: theme.solid,
            backgroundAlpha: 1,
            text: theme.text,
            border: theme.border,
            borderAlpha: 1,
            borderWidth: 2,
            scrim: theme.solid,
            scrimAlpha: 0.5,
            placeholder: theme.text,
            textError: theme.text,
            borderActive: theme.text,
            borderError: theme.text
        };
    }
    readonly property var features: data.features || ({})
    FileView {
        id: file
        path: Quickshell.env("QS_SETTINGS") || Qt.resolvedUrl("generated.json")
        blockLoading: true
        onLoadFailed: console.error("Could not read generated shell settings")
    }
    FileView {
        id: selectedFile
        path: root.data.paths?.themeState || ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            var name = text().trim();
            if (root.data.themes?.[name]) root.selectedTheme = name;
        }
    }
}
