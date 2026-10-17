pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."
import "../services"

// Bind the catalog to the same service objects used by the bar. Stable IDs
// keep the selected action in place while values and toggle states change.
QtObject {
    id: root
    signal openMenu(string name)
    signal powerRequested(string action)
    property var pendingLaunch: []
    property Timer launchDelay: Timer {
        interval: 150
        onTriggered: Runtime.launch(root.pendingLaunch)
    }

    function action(id, title, callback, subtitle, keywords, value, adjust) {
        return {
            id: id,
            title: title,
            action: callback,
            subtitle: subtitle || "",
            keywords: keywords || "",
            value: value || "",
            adjust: adjust || null,
            icon: ""
        };
    }
    function page(id, title, subtitle, keywords, glyph) {
        var item = action(id, title, () => root.openMenu(id), subtitle, keywords);
        item.submenu = true;
        item.glyph = glyph || "";
        return item;
    }
    function launch(args) {
        if (!Config.preview) {
            Runtime.closeMenu();
            // Let the overlay disappear before screenshots or focused-window actions.
            pendingLaunch = args;
            launchDelay.restart();
        }
    }
    function edit(relativePath) {
        launch([Config.bin.kitty, "-e", Config.bin.editor, Config.paths.dotfiles + "/" + relativePath]);
    }
    function setTheme(name) {
        if (Config.preview) return;
        Runtime.run([Config.bin.theme, "set", name], function(code) {
            if (code) Runtime.report("Theme could not be changed");
            else {
                Config.selectedTheme = name;
                Runtime.closeMenu();
            }
        });
    }
    function audioValue(node) {
        return node?.audio ? Math.round(node.audio.volume * 100) + "%" + (node.audio.muted ? " · muted" : "") : "Unavailable";
    }
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "Power saver" : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced"
    readonly property var profiles: PowerProfiles.hasPerformanceProfile ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance] : [PowerProfile.PowerSaver, PowerProfile.Balanced]
    function stepProfile(direction, wrap) {
        var next = profiles.indexOf(PowerProfiles.profile) + direction;
        if (wrap)
            next = (next + profiles.length) % profiles.length;
        if (next >= 0 && next < profiles.length)
            Battery.setProfile(profiles[next]);
    }
    readonly property var presentation: action("presentation", "Presentation mode", () => Runtime.presentation = !Runtime.presentation, "Keep the screen awake", "idle sleep inhibit caffeine", Runtime.presentation ? "On" : "Off")
    readonly property var powerProfile: action("power-profile", "Power profile", () => stepProfile(1, true), "Enter cycles · Ctrl+−/+ steps", "battery saver balanced performance", profile, direction => stepProfile(direction, false))
    readonly property var audio: [action("volume", "Volume", () => Audio.mute(false), Audio.sink?.description || "No output device", "sound speaker output mute unmute", audioValue(Audio.sink), direction => Audio.change(false, direction * 5)), action("microphone", "Microphone", () => Audio.mute(true), Audio.source?.description || "No input device", "mic input volume mute unmute", audioValue(Audio.source), direction => Audio.change(true, direction * 5)), page("audio", "Audio devices", "Choose speakers, headphones or microphone", "sound output input headset")]
    readonly property var notificationActions: [action("dnd", "Do Not Disturb", () => Preferences.dnd = !Preferences.dnd, "Silence notification popups; keep history", "dnd quiet notifications", Preferences.dnd ? "On" : "Off"), page("notifications", "Notification history", Notifications.entries.length + " saved notifications", "alerts messages"), action("clear-notifications", "Clear notifications", () => Notifications.clear(), "Dismiss all saved notifications", "history alerts")]
    readonly property var display: [action("brightness", "Brightness", () => Display.brightness(5), "Screen backlight · Enter increases by 5%", "display screen dim brighter", Display.brightnessPercent < 0 ? "—" : Display.brightnessPercent + "%", direction => Display.brightness(direction * 5)), action("nightlight", "Night light", () => Display.toggleNightlight(), "Warmer screen colours", "display blue light nightlight", Preferences.nightlight ? "On" : "Off"), action("temperature", "Colour temperature", () => Display.toggleNightlight(), "Night light · lower values are warmer", "display color nightlight kelvin", Preferences.nightlight ? Preferences.temperature + " K" : "Off", direction => Display.adjustNightlight(direction * 500)), presentation, action("bar", "Show top bar", () => Preferences.barHidden = !Preferences.barHidden, "Toggle bar visibility", "waybar panel hide show", Preferences.barHidden ? "Off" : "On")]
    readonly property var connections: [page("wifi", "Wi-Fi and network", Networking.wifiEnabled ? "Wi-Fi enabled" : "Wi-Fi disabled", "wifi internet ethernet connections"), page("bluetooth", "Bluetooth", Bluetooth.devices.values.filter(d => d.connected).length + " connected devices", "wireless headphones"), page("battery", "Battery and power profile", profile, "battery saver balanced performance health charge cycles"), page("tray", "System tray", "Open applications and their menus", "icons applets")]
    readonly property var media: [action("play", "Play / pause", () => Media.control("toggle"), Media.player?.trackTitle || "No media playing", "music media playback"), action("previous", "Previous track", () => Media.control("previous"), "Media playback", "music media"), action("next", "Next track", () => Media.control("next"), "Media playback", "music media")]
    readonly property var desktop: [page("calendar", "Calendar", "Browse months and return to today", "clock date time"), page("todos", "Reminders", Reminders.items.length + " open tasks", "todo obsidian notes"), page("workspaces", "Workspaces", "Switch to a desktop", "windows workspace"), page("status", "System status", "Battery, processor, memory and network", "cpu ram temperature"), action("monitor", "System monitor", () => launch([Config.bin.kitty, "--class", "btop-popup", "-e", Config.bin.btop]), "Open btop", "cpu memory ram processes activity"), action("input", "Switch input method", () => {
            if (!Config.preview)
                Runtime.run([Config.bin.inputMethod, "-t"], null);
        }, "Toggle the current Fcitx input method", "keyboard language chinese english layout"), page("apps", "Applications", "Launch an application", "launcher programs"), page("files", "Files", "Browse your home directory", "folders file manager"), page("clipboard", "Clipboard history", "Restore text or images", "copy paste")].concat(media)
    readonly property var capture: [action("screenshot-region", "Screenshot region", () => launch([Config.paths.screenshot, "region"]), "Select an area to capture", "capture snip screen"), action("screenshot-window", "Screenshot window", () => launch([Config.paths.screenshot, "windows"]), "Pick a window; Tab or arrows change the selection", "capture screen"), action("screenshot-screen", "Screenshot screen", () => launch([Config.paths.screenshot, "fullscreen"]), "Capture the current monitor", "capture display"), action("screenshot-edit", "Edit latest screenshot", () => launch([Config.paths.editScreenshot]), "Open the latest capture in Swappy", "capture edit annotate"), action("record", "Start / stop screen recording", () => launch([Config.paths.screenRecord]), "Record the current monitor", "capture video screencast")]
    readonly property var themes: (Config.data.themeOrder || []).map(name => {
        var theme = Config.data.themes[name];
        return action("theme-" + name, theme.displayName, () => setTheme(name), theme.mode === "light" ? "Light theme and wallpaper" : "Dark theme and wallpaper", name + " " + theme.mode + " omarchy", Config.selectedTheme === name ? "Selected" : "");
    })
    readonly property var configuration: [action("keybindings", "Keyboard shortcuts", () => edit("home/files/hypr/keybindings.lua"), "Edit shortcuts in Neovim", "hotkeys bindings settings"), action("hyprland-settings", "Hyprland settings", () => edit("home/files/hypr/hyprland.lua"), "Edit monitor, input and window settings", "display keyboard mouse resolution scale layout"), action("shell-settings", "Bar and shell appearance", () => edit("home/quickshell.nix"), "Edit colours, fonts and shell settings", "appearance colours fonts settings waybar quickshell"), action("desktop-settings", "Wallpaper and idle settings", () => edit("home/desktop.nix"), "Edit the Nix configuration; rebuild to apply", "background sleep settings")]
    readonly property var learn: [page("vim", "Vim reference", "Search editing shortcuts", "help keyboard"), page("lazyvim", "LazyVim reference", "Search editor shortcuts", "help keyboard")]
    readonly property var style: [page("theme", "Theme", "Choose a desktop palette and wallpaper", "style light dark appearance")].concat(configuration.slice(2, 4))
    readonly property var configurationPage: page("configuration", "Configuration files", "Edit your dotfiles in Neovim", "config editor nix")
    readonly property var fingerprint: [action("fingerprint-enroll", "Enroll fingerprint", () => launch([Config.bin.kitty, "-e", Config.bin.fingerprint, "setup"]), "Enroll and verify a fingerprint", "touch id biometric security setup"), action("fingerprint-verify", "Test fingerprint", () => launch([Config.bin.kitty, "-e", Config.bin.fingerprint, "verify"]), "Check that the reader recognizes your finger", "touch id biometric security verify"), action("fingerprint-list", "Enrolled fingerprints", () => launch([Config.bin.kitty, "-e", Config.bin.fingerprint, "list"]), "Show the fingerprints saved for your account", "touch id biometric security status")]
    readonly property var fingerprintPage: page("fingerprint", "Fingerprint", "Unlock the screen and approve administrator prompts", "touch id biometric security sudo polkit")
    readonly property var settings: [page("audio", "Sound", "Speakers, headphones and microphone", "volume audio"), page("display", "Display", "Brightness, scale, text size and night light", "screen monitor"), ...connections.slice(0, 2), page("notifications", "Notifications", "Do Not Disturb and saved notifications", "alerts history"), fingerprintPage, configurationPage, connections[3], desktop.find(item => item.id === "input")]
    readonly property var power: ["Lock", "Suspend", "Hibernate", "Logout", "Reboot", "Shutdown"].map(title => action("session-" + title.toLowerCase(), title, () => root.powerRequested(title.toLowerCase()), "Session and power", title === "Reboot" ? "restart" : title === "Shutdown" ? "power off turn off" : ""))
    readonly property var workspaces: Array.from({
        length: 10
    }, (_, i) => {
        var number = i + 1;
        var workspace = Hyprland.workspaces.values.find(w => w.id === number);
        return action("workspace-" + number, "Workspace " + number, () => {
            if (Config.preview)
                return;
            if (workspace)
                workspace.activate();
            else
                Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + number + " })" : "workspace " + number);
            Runtime.closeMenu();
        }, workspace ? workspace.toplevels.values.length + " windows" : "Empty workspace", "desktop", workspace?.focused ? "Active" : "");
    })
    readonly property var trigger: [page("capture", "Capture", "Screenshots and screen recording", "video")].concat(desktop.filter(item => ["clipboard", "files", "calendar", "todos", "workspaces"].indexOf(item.id) >= 0), media)
    readonly property var system: power.concat([presentation, powerProfile, connections[2]])
    readonly property var home: [
        page("apps", "Apps", "Launch an installed application", "applications launcher programs", "󰀻"),
        page("learn", "Learn", "Keyboard and editor references", "help reference", "󰘥"),
        page("trigger", "Trigger", "Capture, clipboard and desktop actions", "utilities media", "󱓟"),
        page("style", "Style", "Appearance and desktop colours", "appearance colours", "󰏘"),
        page("settings", "Setup", "Devices, connectivity and configuration", "setup settings", "󰒓"),
        page("status", "About", "System information and activity", "about status information", "󰋼"),
        page("power", "System", "Power profiles and session actions", "system power session", "󰐥")
    ]
    // Search finds controls and pickers; their choices stay inside each picker.
    readonly property var all: home.concat([page("display", "Display settings", "Brightness, scale, text size and night light", "monitor screen")], audio, notificationActions, display, [powerProfile], style, connections, desktop, capture, configuration, learn, [fingerprintPage], fingerprint, [configurationPage], power).filter((item, index, items) => items.findIndex(other => other.id === item.id) === index)
}
