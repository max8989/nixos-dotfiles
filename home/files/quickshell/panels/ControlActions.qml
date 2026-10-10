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
    function page(id, title, subtitle, keywords) {
        var item = action(id, title, () => root.openMenu(id), subtitle, keywords);
        item.submenu = true;
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
        launch([Config.bin.editor, Config.paths.dotfiles + "/" + relativePath]);
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
    readonly property var powerProfile: action("power-profile", "Power profile", () => stepProfile(1, true), "Enter cycles · ←/→ steps", "battery saver balanced performance", profile, direction => stepProfile(direction, false))
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
    readonly property var themes: [action("theme-tokyo-night", "Tokyo Night", () => setTheme("tokyo-night"), "Current dark theme", "dark omarchy", Config.selectedTheme === "tokyo-night" ? "Selected" : ""), action("theme-catppuccin-latte", "Catppuccin Latte", () => setTheme("catppuccin-latte"), "Light theme and wallpaper", "light bright", Config.selectedTheme === "catppuccin-latte" ? "Selected" : "")]
    readonly property var style: [page("theme", "Theme", "Choose Tokyo Night or Catppuccin Latte", "style light dark appearance")]
    readonly property var settings: [action("keybindings", "Keyboard shortcuts", () => edit("home/files/hypr/keybindings.lua"), "Edit shortcuts in your dotfiles", "hotkeys bindings settings"), action("hyprland-settings", "Hyprland settings", () => edit("home/files/hypr/hyprland.lua"), "Edit monitor, input and window settings", "display keyboard mouse resolution scale layout"), action("shell-settings", "Bar and shell appearance", () => edit("home/quickshell.nix"), "Edit colours, fonts and shell settings", "theme settings waybar quickshell"), action("desktop-settings", "Wallpaper and idle settings", () => edit("home/desktop.nix"), "Edit the Nix configuration; rebuild to apply", "background sleep settings"), page("vim", "Vim reference", "Search editing shortcuts", "help keyboard"), page("lazyvim", "LazyVim reference", "Search editor shortcuts", "help keyboard")]
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
    readonly property var home: [presentation, powerProfile, page("audio", "Sound", audioValue(Audio.sink) + " · speakers and microphone", "volume audio"), notificationActions[0], notificationActions[1], page("display", "Display", "Brightness, scale, text size and night light", "screen monitor"), page("style", "Style", "Theme and appearance", "theme light dark"), ...connections, page("desktop", "Desktop", "Calendar, reminders, workspaces and media", "utilities"), page("capture", "Capture", "Screenshots and screen recording", "video"), page("settings", "Settings and shortcuts", "Configuration files and keyboard references", "help"), page("power", "Power and session", "Lock, suspend, restart or shut down", "logout")]
    readonly property var all: [page("display", "Display settings", "Brightness, scale, text size and night light", "monitor screen")].concat(audio, notificationActions, display, [powerProfile], style, themes, connections, desktop, capture, settings, power)
}
