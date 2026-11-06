# Omarchy feature review and setup recommendations

Review date: 2026-11-05. Upstream reference: Omarchy v4.5.0.

Screen-to-text OCR, QR decoding, color picking and richer screen recording are
now configured. A dedicated agent console is a useful next addition. This setup
already implements much of Omarchy's everyday desktop experience, so the
priorities below focus on gaps that would improve daily use.

The inventory reflects the repository's working tree on the review date,
including the in-progress wallpaper changes. It describes configured features;
deployment and physical hardware acceptance are separate concerns.

## Features already configured

| Area | Existing features | Local references |
| --- | --- | --- |
| Desktop shell | Quickshell bar, application and file launchers, clipboard history, notifications, Do Not Disturb, system tray, OSD, lock screen and administrator prompts. | [Shell configuration](home/quickshell.nix), [desktop actions](home/files/quickshell/panels/ControlActions.qml) |
| Appearance | Eight runtime themes: Tokyo Night, Catppuccin Latte, Flexoki Light, White, Osaka Jade, Catppuccin Mocha, Gruvbox and Nord. Coordinated application colors, wallpaper import/gallery and persistent wallpaper choices per theme. | [Theme catalog](home/theme-data.nix), [theme generation](home/theme.nix), [wallpaper gallery](home/files/quickshell/panels/WallpaperPanel.qml) |
| Window management | Dwindle tiling, tabbed groups, floating windows, fullscreen/maximize, recent-window Alt-Tab, named desktops and attention indicators. Discord and TickTick share the Super+S scratchpad. | [Bindings](home/files/hypr/keybindings.lua), [window switcher](home/files/quickshell/panels/WindowSwitcher.qml), [workspace service](home/files/quickshell/services/Workspaces.qml) |
| Keyboard and languages | Local French/English dictation with Quebec vocabulary and a waveform HUD; Caps-based navigation; US, Canadian and Chinese Pinyin input with Traditional Taiwanese output. | [Dictation](home/dictation.nix), [input methods](home/fcitx5.nix), [keyboard remapping](home/files/kanata/config.kbd) |
| Capture | Frozen-screen region/window/monitor screenshots, PNG clipboard output, preview notifications, Swappy editing, local English/French/Traditional Chinese OCR, QR-only decoding, hex color picking, region/window/monitor recording with desktop or microphone audio, a recording indicator and completion actions. | [Capture helpers](home/capture-tools.nix), [extraction](home/files/scripts/screenshot.sh), [color picker](home/files/scripts/color-pick.sh), [recorder](home/files/scripts/screen_record.sh) |
| Laptop controls | Audio device selection and microphone testing, Wi-Fi and DNS, display scaling with automatic rollback, brightness, night light, presentation mode, power profiles and fingerprint authentication. | [Settings panels](home/files/quickshell/panels), [fingerprint configuration](hosts/fingerprint.nix) |
| Productivity and sharing | TickTick reminders in the bar and lock screen, LocalSend, removable-drive automounting, and VPN sharing over Wi-Fi or Thunderbolt. | [Reminders](home/files/quickshell/services/Reminders.qml), [desktop services](home/desktop.nix), [VPN sharing](hosts/vpn-hotspot.nix) |
| Server infrastructure | Separate headless profile supporting the media stack, NVIDIA containers, Portainer, Hollama and Open WebUI. | [Server configuration](hosts/homeserver/configuration.nix), [server user profile](home/server.nix) |

The existing Omarchy theme and capture adaptations retain their source details
in [PROVENANCE.md](home/files/omarchy/PROVENANCE.md), including the snapshot
captured on 2026-10-10.

## Relevant additions in Omarchy 4.5

[Omarchy v4.5.0](https://github.com/omacom/omarchy/releases/tag/v4.5.0) was
published on 2026-11-05. Its relevant changes include:

- Floating workspaces with themed titlebars and a dock.
- Independent workspaces per monitor.
- A dedicated Quake agent console and expanded agent usage meters.
- Captive Wi-Fi portal detection and a sign-in action.
- Rebuilt notifications with sender grouping, repeat collapsing, verification
  codes and links.
- Video backgrounds, theme intros, Jade Horse and Starship themes, and the
  Elsewhen world clock.

See the [official 4.5 release notes](https://omarchy.org/news/2026/11/omarchy-4-5/).
The backlog below also includes established Omarchy tools missing from this
setup, such as OCR; it is broader than the changes introduced in 4.5.

## Prioritized feature backlog

Effort estimates are relative assessments from the current code. They are not
implementation commitments.

| Priority | Feature | Local gap and expected benefit | Estimated effort | Upstream reference |
| --- | --- | --- | --- | --- |
| 1 | Screen-to-text OCR, QR decoding and color picking — implemented | Capture menu actions copy English/French/Traditional Chinese text, decode QR codes to a sensitive clipboard selection, and pick hex colors. Extraction uses temporary captures, preserves the clipboard on empty results or failure, and shares cancellation with screenshots. | Complete in configuration; deployment and physical hardware acceptance remain separate | [Capture documentation](https://github.com/omacom/omarchy/blob/v4.5.0/manual/12-screenshots-recording.md) |
| 2 | Dedicated Quake agent console | Provide a persistent dropdown terminal for Claude/Codex while leaving the Discord/TickTick scratchpad available. Both coding agents are already installed. | Small to medium | [Quake console](https://github.com/omacom/omarchy/blob/v4.5.0/manual/04-navigation.md#quake-console) |
| 3 | Richer screen recording — implemented | Region/window/monitor selection, no audio/desktop/microphone controls, an elapsed-time stop indicator and Open/Open folder/Copy path completion actions are configured. Alt+4 retains its monitor toggle. | Complete in configuration; deployment and physical hardware acceptance remain separate | [Screen recording](https://github.com/omacom/omarchy/blob/v4.5.0/manual/12-screenshots-recording.md#screen-recording) |
| 4 | Agent usage panel | Show Claude/Codex usage allowances and reset times in the shell. Agent installation already exists; the desktop dashboard is the missing piece. | Medium | [Agent panel and collectors](https://github.com/omacom/omarchy/blob/v4.5.0/shell/plugins/agents/README.md) |
| 5 | Per-workspace layout switching | Keep ordinary tiling on some desktops and scrolling columns on others for code, documentation and terminals. Full floating desktops with titlebars and a dock can follow as a larger extension. | Medium; larger with dock | [Workspace layouts](https://github.com/omacom/omarchy/blob/v4.5.0/manual/04-navigation.md#dwindle-vs-scrolling-layout) |
| 6 | Independent workspaces per monitor | Give each display its own numbered desktops and restore them after reconnecting. Relevant to the external-monitor and iPad display configuration; current number bindings target global desktops 1 through 10. | Larger | [Monitor workspace implementation](https://github.com/omacom/omarchy/blob/v4.5.0/default/hypr/monitor-workspaces.lua) |
| 7 | Captive Wi-Fi portal handling | Distinguish a Wi-Fi connection from usable internet access and show an Open Captive Portal action. The current network panel handles connection details and DNS but lacks this flow. | Small to medium | [Network panel implementation](https://github.com/omacom/omarchy/blob/v4.5.0/shell/plugins/panels/network/Panel.qml) |
| 8 | Smarter notifications | Add grouping by sender, collapsing of repeated messages, verification-code copying and clickable links. Existing notification actions and workspace highlighting provide a foundation. | Medium | [Notification documentation](https://github.com/omacom/omarchy/blob/v4.5.0/manual/10-notices.md) |

## Suggested first implementation batch

- [x] Add OCR, QR decoding and color picking to the capture menu.
- [ ] Add a dedicated agent dropdown console.
- [x] Add audio/region controls, a visible stop indicator and actionable completion notifications for recording.

These additions extend workflows that already exist in the repository. Retain
the local bilingual dictation setup while prioritizing these gaps.

## Integration constraints

Preserve the existing shortcuts when adapting upstream behavior:

| Shortcut | Current local action | Omarchy 4.5 action |
| --- | --- | --- |
| Super+L | Focus the window to the right | Cycle workspace layout |
| Super+M | Open desktop controls | Minimize to the dock |
| Alt+Space | Open the application launcher | Toggle dictation |

Local bindings live in [keybindings.lua](home/files/hypr/keybindings.lua);
upstream behavior is described in the
[4.5 release notes](https://omarchy.org/news/2026/11/omarchy-4-5/).

Adapt additions to the repository's existing declarative Nix and custom
Quickshell structure. Keep runtime preferences outside immutable bundles,
declare helper dependencies, and preserve upstream licenses and provenance.
See [repository conventions](CLAUDE.md).

For monitor workspace changes, preserve desktop names, attention indicators
and Alt-Tab behavior, and verify display disconnect/reconnect handling.

## Optional appearance additions

Jade Horse and Starship themes, video wallpapers and the Elsewhen world clock
are additional candidates after the workflow improvements. Their upstream
overview is in the
[4.5 release notes](https://omarchy.org/news/2026/11/omarchy-4-5/).
