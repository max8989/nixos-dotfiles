pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import ".."
import "../widgets"

Scope {
    id: root
    PolkitAgent {
        id: agent
        onIsActiveChanged: {
            if (isActive && Runtime.locked)
                flow.cancelAuthenticationRequest();
        }
    }
    Connections {
        target: Runtime
        function onLockedChanged() {
            if (Runtime.locked && agent.isActive)
                agent.flow.cancelAuthenticationRequest();
        }
    }
    IpcHandler {
        target: "auth"
        function isRegistered(): bool {
            return agent.isRegistered;
        }
        function isActive(): bool {
            return agent.isActive;
        }
    }
    PanelWindow {
        visible: agent.isActive && !Runtime.locked
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Qt.alpha(Config.surface("polkit").scrim, Config.surface("polkit").scrimAlpha)
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-auth"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: {
            password.text = "";
            if (visible)
                focusDelay.restart();
        }
        Glass {
            surface: "polkit"
            width: Math.min(500, parent.width - 40)
            height: content.implicitHeight + 48
            anchors.centerIn: parent
            ColumnLayout {
                id: content
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: Config.spacing.panelPadding
                }
                spacing: Config.spacing.panelGap
                Text {
                    text: "Authentication required"
                    color: Config.theme.accent
                    font.family: Config.theme.uiFont
                    font.pixelSize: Config.fonts.display
                }
                Text {
                    text: agent.flow?.message || ""
                    color: Config.theme.text
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                }
                ComboBox {
                    visible: (agent.flow?.identities.length || 0) > 1
                    model: agent.flow?.identities || []
                    textRole: "displayName"
                    onActivated: if (agent.flow)
                        agent.flow.selectedIdentity = model[currentIndex]
                }
                Text {
                    text: agent.flow?.inputPrompt || ""
                    color: Config.theme.dim
                    textFormat: Text.PlainText
                }
                TextField {
                    id: password
                    Layout.fillWidth: true
                    color: Config.theme.text
                    echoMode: agent.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                    enabled: !!agent.flow?.isResponseRequired
                    background: Rectangle {
                        color: Config.theme.surface
                        radius: 9
                        border.color: Config.theme.accent
                    }
                    onAccepted: {
                        if (agent.flow?.isResponseRequired)
                            agent.flow.submit(text);
                        text = "";
                    }
                    Keys.onEscapePressed: if (agent.flow)
                        agent.flow.cancelAuthenticationRequest()
                }
                Text {
                    text: agent.flow?.failed ? "Authentication failed. Try again." : agent.flow?.supplementaryMessage || ""
                    color: Config.theme.warning
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    textFormat: Text.PlainText
                }
                RowLayout {
                    Chip {
                        text: "Cancel"
                        onClicked: if (agent.flow)
                            agent.flow.cancelAuthenticationRequest()
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Chip {
                        text: "Authenticate"
                        enabled: !!agent.flow?.isResponseRequired
                        onClicked: password.accepted()
                    }
                }
            }
        }
    }
    Timer {
        id: focusDelay
        interval: 50
        onTriggered: password.forceActiveFocus()
    }
    Connections {
        target: agent.flow
        function onIsResponseRequiredChanged() {
            password.text = "";
            if (agent.flow.isResponseRequired)
                focusDelay.restart();
        }
    }
}
