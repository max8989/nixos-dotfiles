# Omarchy 4.5 feature catalog

Research date: 2026-11-15. Upstream: [Omarchy v4.5.0](https://github.com/basecamp/omarchy/releases/tag/v4.5.0)
("Quattro RS", published 2026-11-05; 740+ PRs from 180+ contributors over
twelve weeks). Sources: the
[official announcement](https://omarchy.org/news/2026/11/omarchy-4-5/), the
v4.5.0-rc1/rc2/rc3 release notes, and the `quattro` branch of the repository.

This file is a **complete catalog** of what changed and whether it applies to
this NixOS config. The prioritized work queue lives in
[OMARCHY-FEATURE-REVIEW.md](OMARCHY-FEATURE-REVIEW.md); this file does not
replace it.

**Status legend**

- **Have** — already implemented here (verified in the repo, or recorded as
  implemented in the review file).
- **Port** — a good fit; worth adapting.
- **Maybe** — fits, but a larger design change or a taste decision.
- **Skip** — Arch/installer/hardware-specific or already solved differently.

Items marked *(per review)* come from `OMARCHY-FEATURE-REVIEW.md` and were not
re-verified in the code for this file.

---

## 1. Desktop and window management

| Feature | What upstream did | Status | Notes for this repo |
| --- | --- | --- | --- |
| Floating workspaces + dock | `Super+L` cycles a workspace between dwindle, scrolling and floating. Floating workspaces give every window a themed titlebar, plus a dock with pinned apps, running apps and an all-apps grid (drag to reorder or pin, right-click menu, position and auto-hide under Appearance > Dock). `Super+M` minimizes to the dock. The bar shows each workspace's layout. | Maybe | Headline feature, largest port: needs a Quickshell dock plus per-workspace layout state. Collides with `Super+L` (focus right here) and `Super+M` (desktop controls here). |
| Per-monitor workspaces | `Super+1-0`, `Super+Tab` and `Super`+scroll stay on the current monitor's own workspace set, remembered across reconnects. `Super+Arrows` crosses displays, `Super+Shift+Ctrl+Arrows` moves a window to another monitor. Upstream: `default/hypr/monitor-workspaces.lua`. | Port | `keybindings.lua` currently binds `Super+1-0` to global workspaces. `hyprland.lua` already has dock/monitor-ordering workarounds. Preserve named desktops, attention indicators and Alt-Tab. |
| Per-workspace layout (dwindle / scrolling) | Part of the `Super+L` cycle; `Super+Alt+L` returns to the previous layout. | Port | Medium effort without the dock. Only `togglesplit` (dwindle) is bound here today. |
| Quake-style console | `Super+Grave` drops a centered, dimmed terminal over the desktop and starts the default agent on first open; `Super+Shift+Grave` sends a window there. The full-size scratchpad stays on `Super+S`. | Port | Second special workspace next to `magic`. Listed as backlog priority 2 in the review. |
| Full-screen desktop toggle | `Super+Ctrl+Alt+F`. | Maybe | Hides the shell chrome. |
| Select-all and terminal clipboard keys | `Super+A` select all; in terminals `Super+C`/`Super+V` now send `Ctrl+Shift+C`/`Ctrl+Shift+V` (was `Ctrl+Insert`/`Shift+Insert`). `Super+Q` is a second close-window chord. | Port | Small. Check against existing binds first. |
| `o.rebind` | Helper for replacing Hyprland default bindings. | Skip | Omarchy's override layer; this repo owns `keybindings.lua` directly. |
| Scroll workspaces from the bar | Mouse wheel on the bar steps workspaces. | Port | Small; `bar/Bar.qml`. |
| Bar widgets in the tray drawer / drag off to remove | Widgets can live in the tray drawer; dragging a widget off the bar removes it. | Maybe | Only if the bar gains user-configurable widgets. |
| Panels grow out of the bar and morph | Animated panel transitions with press feedback on buttons and bar icons. | Maybe | Polish. |
| Window transparency and corners | Appearance menu: Opaque / Transparent / Glassy windows, a Glassy bar, theme / sharp / rounded corners. Apps are opaque by default, terminals stay transparent. | Maybe | Would need runtime Hyprland settings; today these live in `hyprland.lua`. |
| No-animations mode | Off switch for animations; on by default in VMs. | Port | Small; fits the VM test story. |
| Keyboard backlight | `Ctrl` + brightness keys adjust the keyboard backlight. | Port | ThinkPad has a keyboard backlight; check `brightnessctl --list`. |
| Compose key | Caps Lock returns to normal, `Shift+Caps` becomes compose. | Skip | This repo uses Caps-based navigation via kanata. |

## 2. Notifications

| Feature | What upstream did | Status | Notes |
| --- | --- | --- | --- |
| Stack by sender, collapse identical repeats | Cards group per sender; identical notifications merge. | Port | `services/Notifications.qml`. |
| Actions, codes, links on the card | Buttons, verification codes and links work from the card. | Port *(per review)* | Verification-code copy and clickable links are the missing parts; actions already work. |
| Keyboard control of cards | `Super+Comma` acts on the newest card (dismiss / open / press its single button); `Super+Ctrl+Comma` hands over the keyboard (number keys press buttons, `Enter` clicks, arrows move). `Super+Alt+Comma` dismisses the last; `Super+Ctrl+Alt+Comma` silences. | Port | Check Comma-chord collisions. |
| Do Not Disturb + bell | Bar bell toggles DND. | Have | `Preferences.dnd` exists. |
| 24-hour history | `Super+Shift+Alt+Comma` shows the last day of notifications. | Port | Needs persisted history under XDG state. |
| Hover close button, slide-in under the bar | Toast polish. | Port | Small. |
| Action buttons via CLI | `omarchy-notification-send` accepts action buttons; screenshot notifications get Open/Edit, recordings and downloads Open/Cut. | Have *(per review)* | Recording Open / Open folder / Copy path already done. |
| Mute from crash diagnosis | Mute a program's notifications from its crash report. | Skip | Omarchy's crash-diagnosis tool. |

## 3. Appearance, themes and wallpapers

| Feature | What upstream did | Status | Notes |
| --- | --- | --- | --- |
| Appearance menu | One top-level menu replacing Style: theme, background, font, bar, windows (gaps, corners, opacity, one-window ratio), branding, dock, per-workspace layout, animations, unlock screen. | Maybe | Would extend `panels/Menus.qml`. |
| New default themes | **Jade Horse** (replaces Osaka Jade among defaults; Osaka Jade lives on as a third-party theme) and **Starship**. | Port | Add to `home/theme-data.nix`; keep license/provenance in `home/files/omarchy/`. This repo ships Osaka Jade today. |
| New backgrounds | Liftoff (new Tokyo Night default, by Tom Ballard), Roadster Starlight (Ethereal), Flexoki Light intro. | Port | Check each asset's license before copying. |
| Per-theme remembered wallpaper | Each theme restores its own selected background. | Port | `home/theme.nix` + `desktop-theme`. |
| Video wallpapers | Backgrounds may be videos (played by OWE); lock screen shows a still frame. | Maybe | Needs a video wallpaper player; Hyprpaper is stills only. |
| Theme intros | Short silent intro on login and on theme switch; toggle under Appearance > Animations. | Skip | Cosmetic; depends on the video pipeline. |
| Delete extra themes from picker | Remove installed third-party themes. | Skip | Themes here are declarative. |
| Live editor theming | VS Code-family editors follow theme changes live; running Hunk sessions retheme; theme sync to herdr machines. | Have / Maybe | VS Code is already themed here; herdr theme sync is a possible follow-up (repo has recent herdr work). |
| Faster theme picker | Opens immediately instead of after ~245 ms. | Skip | Different implementation. |

## 4. Input, languages and dictation

| Feature | What upstream did | Status | Notes |
| --- | --- | --- | --- |
| 50 languages, live switch | `Setup > Language` / `omarchy language <code>`. | Skip | Single-user config; locale is set declaratively. |
| Five input methods | Mozc (Japanese), Hangul, Pinyin, Zhuyin, Cangjie with fonts and a themed candidate window; `Super+I` switches input language; Shift alone toggles Latin. | Have (partly) | fcitx5 with Pinyin and Traditional Taiwanese output is configured. Zhuyin/Cangjie/Japanese/Korean would be additions. |
| Superwhisper / Voxtype dictation | Superwhisper default (cloud first, local model optional); `Alt+Space` toggles, holding `Right Alt` is push-to-talk. | Have | Local French/English dictation with a waveform HUD is already built from Omarchy's Voxtype backend. `Alt+Space` is the launcher here. |
| CJK input from installer | Installer option. | Skip | Installer-only. |

## 5. Capture, network and system

| Feature | What upstream did | Status | Notes |
| --- | --- | --- | --- |
| Screenshots (Omasnap) | Replaces Tensaku; `Super+Ctrl+Alt+C` shortcut. | Have | Own packaged capture helpers (`home/capture-tools.nix`). |
| OCR / QR / color picker / recording | Established Omarchy tools. | Have *(per review)* | Implemented in the capture menu. |
| Captive-portal sign-in | Network icon warns; panel shows an "Open Captive Portal" button; connectivity checked against Omarchy's own endpoint. | Port | Small to medium; `NetworkManager` exposes connectivity state. Use a neutral check URL instead of Omarchy's endpoint. |
| BBR + kyber | TCP congestion control switched to BBR; kyber I/O scheduler on real disks. | Port | `boot.kernel.sysctl` plus a udev rule in `hosts/common.nix`. Confirm option names before writing; no BBR/scheduler setting exists in `hosts/` today. |
| Hardware video decode in mpv, Chromium overlay scrollbars | Defaults. | Port | Small, only if mpv/Chromium are managed here. |
| Network speed test, geo/ntp from Omarchy servers | Own endpoints for weather location, time, speed test. | Skip | Vendor-hosted; don't depend on them. |
| Tailscale panel speedup | Faster on tailnets with thousands of machines. | Skip | |
| Fingerprint enrollment guide | Step-by-step enrollment; removes fingerprints from reader storage. | Have | Fingerprint workflow already adapted from Omarchy. |
| Passwordless sudo duration | User-chosen length; asked once per ten minutes. | Skip | Arch-side `sudo` policy. |
| Memory-pressure policy | (Earlier Omarchy work.) | Have | Adapted into this repo already. |
| gliff remote desktop over SSH | Drive another Omarchy machine's desktop from a window; remote-session indicator in the bar. | Maybe | Omarchy-specific; consider only if wanted for the homeserver. |

## 6. Apps and services

| Feature | What upstream did | Status | Notes |
| --- | --- | --- | --- |
| Hype | Markdown presentations with a visual editor; exports PDF/PPTX. | Skip | Omarchy ecosystem package. I haven't checked whether nixpkgs has it; run `nix search nixpkgs` if interested. |
| Signed | PDF signing; replaces Xournal++. | Maybe | Look for a nixpkgs equivalent. |
| Disktree | Disk-usage treemap with safe-to-regenerate cache callouts; replaces the Disk Usage TUI. | Maybe | Useful on the btrfs laptop; verify availability. |
| Monologue | One-key camera recording; replaces OBS/Kdenlive on new installs (paired with Omacut). | Skip | |
| Elsewhen world clock | Bar widget + panel: city rows, daylight strip, weather, people, spinnable globe; `Super+Ctrl+Alt+E`. MIT-licensed QML plugin (about 280 KB) under `shell/plugins/panels/elsewhen/`. Coupled to Omarchy's `qs.Commons`/`qs.Ui` plugin API and `shell.json`. | Maybe | Port the idea, not the code: rows + daylight strip + city search over `/usr/share/zoneinfo`; drop globe and greetings. Uses Open-Meteo (keyless) for weather and place search if included. |
| Agents panel | Tracks 23 agents/providers (up from 6) with per-limit meters and reset times; Grok first-class; multiple Claude/Codex/Grok logins via `omarchy agent account`; one-click switch near limits; `account copy` over SSH. | Maybe | "Agent usage panel" is backlog priority 4. Account switching is Omarchy-specific tooling. |
| New agent defaults | Kimi, Ori, Antigravity (replaces Gemini CLI); Claude and Amp desktop apps under Install > AI. | Skip | Packages, not config. |
| Microsoft 365 web apps | Outlook, Word, Excel, PowerPoint, Teams, OneDrive as web apps. | Skip | Web-app launchers; trivial but not wanted by default. |
| Slack, SSH agent, hey/basecamp/Cloudflare CLIs, vi | Optional installs. | Skip | |
| Lazydocker, OBS, Kdenlive removed from new installs | Deprecations. | Skip | Not relevant to declarative installs. |

## 7. Installer, boot and platform

| Feature | What upstream did | Status |
| --- | --- | --- |
| F1 installer | Prebuilt root image plus machine-specific packages; install about 2x faster (7 s record on fast AMD hardware). | Skip — this repo installs via disko + nixos-anywhere / `nixos-install`. |
| Quiet 1-second boot menu | Limine waits 1 s, silent boot; tap a key for the menu. | Skip — different bootloader setup. |
| Apple Silicon (M1/M2/M3/Neo) native installer | Merged "Omarchy Mac" into Omarchy. | Skip |
| ARM ISO; NVIDIA DGX Spark / N1X; Snapdragon | First ARM ISO, preliminary support. | Skip |
| Language/keyboard/timezone presets, China mirrors | Installer media options. | Skip |
| Update flow (kernel menu, orphan removal, AUR, single sudo prompt) | Arch update tooling. | Skip |
| Performance work | Menus and panels open straight from Hyprland binds (about 60 ms saved), the desktop reacts to changes instead of polling, faster prompt (about 30 ms). | Maybe — the "react instead of poll" principle is worth checking in Quickshell services. |

## 8. Security items worth noting

Most are Omarchy scripts and don't apply, but a few are good habits to confirm
in this repo:

- Screen-recording state moved out of world-writable `/tmp` (already a rule
  here: runtime state lives under XDG state/runtime directories).
- Hook and state names that are paths are refused (relevant to any helper that
  builds file names from user input).
- SSH setup must not leave password logins on when no key is added (check the
  server's `services.openssh` settings).
- Windows VM password kept out of RDP client arguments (general principle: no
  secrets in argv).

## 9. Hotkey collisions with this repo

Upstream defaults that overlap bindings in
[`home/files/hypr/keybindings.lua`](home/files/hypr/keybindings.lua), plus
moved shortcuts:

| Upstream | Upstream action | Local use / risk |
| --- | --- | --- |
| `Super+L` | Cycle workspace layout | Focus right here |
| `Super+M` | Minimize to dock | Desktop controls here |
| `Alt+Space` | Toggle dictation | Application launcher here |
| `Super+Q` | Close window | Check for an existing bind |
| `Super+A` | Select all | Check |
| `Super+Grave`, `Super+Shift+Grave` | Quake console | Free unless bound |
| `Super+S` | Full scratchpad | Same meaning as here |
| `Super+Ctrl+Alt+C / E / F` | Screenshot / world clock / full-screen desktop | Check |
| `Super+Shift+Q`, `Super+Shift+T`, `Super+Ctrl+N` | Calculator / Activity / Network (moved) | Only if adopting those actions |
| `Super+Ctrl+T`, `Super+Ctrl+W` | Themes / Backgrounds | Only if adopting |
| Comma chords | Notification control | Check before porting notifications |

## 10. Suggested order

1. **Small, low-risk batch:** BBR + kyber, Quake console, terminal clipboard
   keys, `Super+Q` close, keyboard backlight, no-animations mode.
2. **Per-monitor workspaces**, then per-workspace layout switching.
3. **Notification upgrades:** grouping, history, verification codes, links.
4. **Appearance:** Jade Horse and Starship themes, per-theme wallpaper memory.
5. **Captive-portal handling** in the network panel.
6. **Optional:** world clock (trimmed), agents usage panel, dock/floating mode.

Follow [CLAUDE.md](CLAUDE.md) when implementing: declare helper dependencies
explicitly, keep runtime state out of the immutable Quickshell bundle, verify
Nix option names before writing them, run `nix flake check`, and preserve
upstream license and provenance (see
[home/files/omarchy/PROVENANCE.md](home/files/omarchy/PROVENANCE.md)).

## Sources

- [Omarchy 4.5 announcement](https://omarchy.org/news/2026/11/omarchy-4-5/)
- [v4.5.0 release](https://github.com/basecamp/omarchy/releases/tag/v4.5.0),
  [rc1](https://github.com/basecamp/omarchy/releases/tag/v4.5.0-rc1),
  [rc2](https://github.com/basecamp/omarchy/releases/tag/v4.5.0-rc2),
  [rc3](https://github.com/basecamp/omarchy/releases/tag/v4.5.0-rc3)
- [Elsewhen documentation](https://github.com/basecamp/omarchy/blob/quattro/docs/elsewhen.md)
  and [plugin source](https://github.com/basecamp/omarchy/tree/quattro/shell/plugins/panels/elsewhen)
- [Omarchy manual](https://github.com/basecamp/omarchy/tree/quattro/manual)
