pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Networking
import Quickshell.Services.UPower

QtObject {
    id: root
    property QtObject audio: QtObject {
        id: sound
        property QtObject speakers: QtObject {
            property string name: "qa-speakers"
            property string description: "Laptop speakers"
            property bool isSink: true
            property QtObject audio: QtObject { property real volume: 0.5; property bool muted: false }
        }
        property QtObject headphones: QtObject {
            property string name: "qa-headphones"
            property string description: "USB headphones"
            property bool isSink: true
            property QtObject audio: QtObject { property real volume: 0.65; property bool muted: false }
        }
        property QtObject microphone: QtObject {
            property string name: "qa-mic"
            property string description: "Built-in microphone"
            property bool isSink: false
            property QtObject audio: QtObject { property real volume: 0.8; property bool muted: false }
        }
        property var sink: speakers
        property var source: microphone
        property var sinks: [speakers, headphones]
        property var sources: [microphone]
        function setVolume(input, percent) { (input ? source : sink).audio.volume = percent / 100; }
        function mute(input) { var node = input ? source : sink; node.audio.muted = !node.audio.muted; }
        function select(node) { if (node.isSink) sink = node; else source = node; }
    }
    property QtObject network: QtObject {
        id: wifi
        property bool enabled: true
        property bool hardwareEnabled: true
        property bool changingDns: false
        property QtObject home: QtObject {
            property string name: "Home network"
            property bool connected: true
            property bool known: true
            property bool stateChanging: false
            property real signalStrength: 0.91
            property int security: WifiSecurityType.Wpa2Psk
            function disconnect() { connected = false; }
            function connect() { connected = true; }
        }
        property QtObject guest: QtObject {
            property string name: "Guest Wi-Fi"
            property bool connected: false
            property bool known: false
            property bool stateChanging: false
            property real signalStrength: 0.75
            property int security: WifiSecurityType.Wpa2Psk
            property bool passwordReceived: false
            signal connectionFailed(int reason)
            function connect() { connectionFailed(ConnectionFailReason.NoSecrets); }
            function disconnect() { connected = false; }
            function connectWithPsk(password) {
                passwordReceived = password === "test-password";
                if (passwordReceived) { connected = true; known = true; wifi.home.connected = false; }
            }
        }
        property var active: guest.connected ? guest : home.connected ? home : null
        property var networks: [home, guest]
        property var traffic: ({receiving: 204800, sending: 51200, rx: 104857600, tx: 26214400})
        property var details: ({address: "192.0.2.10/24", gateway: "192.0.2.1", dns: "192.0.2.1", band: "6 GHz", preset: "auto"})
        function toggle() { enabled = !enabled; }
        function setDns(value) { details = Object.assign({}, details, {preset: value}); }
        function advanced() {}
    }
    property QtObject battery: QtObject {
        property bool present: true
        property int percent: 72
        property string summary: "Discharging · 4 h 25 min remaining"
        property var details: ({model: "ThinkPad battery", capacity: 53.4, health: 94, cycles: 121, start: 0, end: 100})
        property int profile: PowerProfile.Balanced
        property bool hasPerformanceProfile: true
        property string degradation: ""
        function setProfile(value) { profile = value; }
    }
}
