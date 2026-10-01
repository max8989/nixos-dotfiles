# Handoff — custom Quickshell desktop

**Updated:** 2026-09-28
**Status:** Desktop controls and the four settings panels are active in the g12
user session. The running bundle matches the tested source and all four direct
shortcuts are registered. The final system generation is built; its activation
requires the user's sudo password. Preferences remain outside the Nix store.

## Settings panels

- Super+Ctrl+A/W/D/P opens Audio/Wi-Fi/Display/Battery. Super+M and the bar
  reach the same panels. Night-light left-click opens Display; right-click
  retains its toggle. Battery and power-profile bar buttons open Battery.
- Panels support Tab/Shift+Tab, Left/Right sliders, Enter/Space, Escape and
  automatic scrolling to keyboard focus. Their height follows the content.
- Native PipeWire controls output/input volume, mute and devices; both default
  device choices persist. The microphone meter runs only after selecting Test
  mic and stops when the panel closes.
- Wi-Fi uses the native network model for radio, scanning and connection/password
  handling. The small packaged Python helper reads IP/gateway/DNS/band data and
  applies IPv4+IPv6 DNS presets through NetworkManager. Failed reapply restores
  the saved profile. Hidden networks/custom DNS remain accessible in nmtui.
- Display offers laptop backlight, panel font size, supported scale presets,
  night light and keep-awake. An independent helper reverts scale on timeout,
  closed stdin or termination. Confirmed values persist by display description
  and are reapplied after login, monitor addition and compositor config reload.
  Revert receives initial confirmation focus; normal focus returns afterwards.
- Battery shows native UPower state and kernel capacity, health, cycles and
  charge thresholds. Power profile buttons remain in the panel after selection.
  Charge thresholds are read-only; panel font size affects these four panels.
- Final bundle: `/nix/store/wkyl27i3lpys7wbxjqgs363q3841d4bk-quickshell-desktop`.
  Final system: `/nix/store/2ydvq4dmc9mr1xxsf3m01ilvpjlnihz1-nixos-system-thinkpad-x1-carbon-g12-26.11.20260907.dc5d91f`.
- Validation: flake checks and complete system/user builds pass; 10 helper
  regressions cover DNS rollback, IPv6, scale validation/quoting, timeout/EOF
  rollback and confirmed persistence. The full isolated UI suite passes all
  22 menus, settings keyboard interactions, Wi-Fi credentials, scale confirmation,
  compact layouts and existing clipboard/notification/power regressions.
  Results: `/tmp/quickshell-settings-final-qa/result.json`.
- Real hardware readers confirmed 53.4 Wh capacity, 94% health, 121 cycles,
  a 100% charge limit, current Wi-Fi details, and valid eDP-1 scale presets.
  UI tests use isolated fixtures; they do not change physical DNS, audio routing,
  display scale, or power profiles.
- Live activation verified the exact final bundle, Super+Ctrl+A/W/D/P registration,
  an active user service, and no Hyprland configuration errors. Audio and Wi-Fi
  rendered correctly with physical devices; the current shell invocation has no
  QML errors. The existing desktop-portal registration warning remains unrelated.

## Desktop controls

- Super+M opens the searchable controls menu. Exact action titles rank ahead
  of matches in descriptions; aliases include `dnd`, `wifi` and `restart`.
- Sound, microphone, brightness, night light, DND, connectivity, power profiles,
  media, workspaces, calendar, notifications, reminders, clipboard, capture,
  source settings and tray application menus share the existing shell services.
- Up/Down selects, Enter opens or toggles, and Left/Right adjusts levels.
  Escape/Alt+Left goes back and restores the parent query/selection. Ctrl+L
  selects the search text. Calendar and notification actions have keyboard focus.
- Logout, reboot, shutdown and hibernate focus Cancel first and require an
  explicit confirmation. The isolated fixture records the power signal without
  taking any real session action.
- Preferences now use `$XDG_STATE_HOME/quickshell-desktop` with mode 0700.
  The former `quickshell/desktop` path was a config alias into the Nix store,
  causing saves to fail. The UI regression fixture reproduces that alias and
  verifies that DND saves outside it.
- Validation: both Nix checks pass; the private Sway harness passes 21 menus,
  live DND/backlight state, ranked search, submenu history, calendar, notification
  focus, visible confirmation focus, clipboard regressions and monitor layouts.
  Latest results: `/tmp/quickshell-controls-persistence-qa/result.json`.

## Decisions and scope

- Full shell: bar, menus, OSD, notifications, tray, polkit and session locking.
- Keep the jade palette, Chinese lock content and existing keyboard shortcuts.
  `home/palette.nix` shares colours across Quickshell, Hyprland, Kitty, Starship,
  fzf, Superfile and the GTK/Qt themes. The desktop wallpaper is rendered from
  `home/files/backgrounds/jade-landscape.svg`. KDE needs both the Qt palette and
  `kdeglobals`' `UiSettings.ColorScheme` default; otherwise KColorSchemeManager
  can replace the colours with Breeze while Kvantum still draws dark widgets.
  The shell palette is defined in Nix; other applications keep their existing theme.
- Use the flake's pinned nixpkgs Quickshell **0.3.1**, with no third-party shell
  configuration or additional flake input. Both `quickshell` and `qs` are present.
- The user retired g7: its flake entry and host files have been deleted.
  `homeserver` remains headless and does not enable Quickshell.
- The migration remains one working-tree change, not the six separately
  committed stages proposed in the original evaluation.

## Tooltip and clipboard follow-up

- Native `PopupWindow` tooltips sit below bar icons, use the existing palette and
  UI font, wrap long details and slide inside screen edges. Preview bars put them
  above. Hover cards dismiss on click, scrolling, menu opening and locking.
- Bar controls use animated hover/pressed fills and keyboard-only focus rings.
  Enabled toggles and the currently open menu have a soft cyan fill. Bar menus
  open near their control; keyboard launchers remain centered.
- `cliphist` 0.7 rejects a bare numeric ID followed by a newline. The helper now
  passes the ID as an argument and decodes to a private temporary file before
  calling `wl-copy`, preserving both binary images and the existing clipboard
  when decoding fails. The picker closes only after success and refreshes stale
  rows on failure. Message toasts wrap text and omit the percentage/progress bar.
- Design references: [Noctalia's Quickshell tooltip](https://github.com/noctalia-dev/noctalia-shell/blob/v4.7.0/Modules/Tooltip/Tooltip.qml)
  and [Caelestia's bar popouts](https://github.com/caelestia-dots/shell/tree/main/modules/bar/popouts).
  These inspired the treatment; no third-party shell code or dependency was added.
- The smoke harness now also imports the built components into an isolated
  fixture, uses Qt's mouse test API to check tooltips/menu anchoring and focus,
  and exercises text/PNG clipboard round trips plus stale-entry recovery on a
  private Wayland selection. Its diagnostic IPC exists only in the test fixture.

## Implementation

`home/quickshell.nix` builds an immutable bundle containing the authored QML and
one generated JSON. It owns palette, fonts, layout, feature toggles, username,
paths and absolute executable paths. Assets are explicit store dependencies.

```
home/files/quickshell/
  shell.qml                 # screen variants, lazy lock/polkit, IPC
  Config.qml                # generated JSON and environment overrides
  Preferences.qml           # mutable state, atomic writes, recovery defaults
  Runtime.qml               # menu/OSD state, process execution, session actions
  Logic.js                  # parsing, metrics, search and battery thresholds
  bar/Bar.qml               # per-screen bar, workspace/title/tray widgets
  services/                 # shared native services and file readers
  panels/                   # menus, calendar, notifications/OSD, polkit
  lock/                     # session-lock protocol, PAM and Chinese lock view
  widgets/                  # shared visual components
  assets/                   # Chinese phrases and Vim/LazyVim references
```

The bar includes workspaces and scrolling, active title, clock/calendar, todos,
CPU and temperature, memory, network, audio/microphone, Bluetooth, night light,
presentation mode, power profiles, battery and notifications. Narrow displays
hide secondary widgets; the system-status menu retains access to their data.

Menus cover applications, clipboard (including image restoration), files,
Vim/LazyVim references, reminders, audio devices, Wi-Fi, Bluetooth, power,
profiles, notifications, calendar and status. NetworkManager, PipeWire, BlueZ,
UPower, MPRIS and tray interfaces use Quickshell services. Advanced Wi-Fi and
Bluetooth pairing open nmtui and Blueman. CPU/memory/network counters and hwmon
temperatures use FileView with in-process timers, not polling shell scripts.

Notification history is bounded to 100 entries, with replacement, actions,
images, expiration and DND. Battery threshold alerts use hysteresis and reset
when charging. Reminders retain the existing Obsidian paths. The lock retains
blurred screenshots, Chinese date/phrases, weather, reminders and media metadata.

The old Waybar, Wofi/Rofi, SwayNC, SwayOSD, wlogout, Hyprlock and GNOME polkit
configuration/packages and their replaced helper scripts are removed. Hypridle,
Hyprpaper, Hyprsunset, Hyprshell Alt-Tab, clipboard capture and independent
screenshot/recording/RSS utilities remain.

## Service, state and security

The Home Manager user service follows `graphical-session.target` and `tray.target`,
restarts on failure, logs to the journal and uses a private umask. File watching
is disabled for production. Its `QS_SETTINGS` environment contains the bundle
store path, so a QML-only change also changes the unit and triggers a restart.

Launch and IPC both select `--config desktop`. Quickshell 0.3.1 distinguishes a
symlink path from its store target; mixing `--path <store-bundle>` at launch with
`--config desktop` for IPC does not work. The isolated UI harness covers this.

Preferences live under `$XDG_STATE_HOME/quickshell-desktop` (falling back to
`~/.local/state`), never in the Nix store. Development previews use separate state
and do not own notifications, tray, polkit or session locking. Hardware and
session actions are disabled in preview.

Unlock requires PAM success. Password and fingerprint conversations use separate
PAM services; the fingerprint stack ends with `pam_deny` if no fingerprint matches.
There is no unlock IPC. Suspend/hibernate actions wait for the compositor's secure
lock signal. Hypridle's sleep inhibitor waits for locking too.

A runtime marker scoped to the compositor instance allows lock recovery after a
shell crash; Hyprland's `allow_session_lock_restore` is enabled. The compositor
keeps the session covered while the shell is absent. Screenshots stay in the
private runtime directory and are removed after unlock.

## Verification

```sh
nix flake check
nix build .#quickshell-config --no-link
nix build .#quickshell-vm-test --no-link
nix build .#nixosConfigurations.thinkpad-x1-carbon-g12.config.system.build.toplevel --no-link
nix develop .#quickshell
python3 tests/quickshell-smoke.py /nix/store/…-quickshell-desktop /tmp/quickshell-smoke
```

- **Flake checks:** QML syntax/import/property lint, Lua syntax including generated
  commands, parsing/state/metrics/battery logic, desktop/headless integration and
  absence of g7. Specific upstream QML metadata defects are allowlisted in
  `tests/quickshell-lint.py`; unknown properties/import errors remain failures.
- **UI harness:** private headless Sway and D-Bus session, fixture applications and
  todos, 14 menus, search/Enter/Escape, negative IPC arguments, named config lookup,
  monitor hotplug, fractional scale, compact layout and preview isolation.
- **NixOS VM:** real PAM password failure/success, no unlock method, notification
  expiry/replacement/DND, polkit cancellation and successful authorization, asset
  closure, killed lock client leaving the desktop covered, restart recovery and
  authentication after recovery. Test credentials and policy exist only in the VM.
- **System:** complete g12 toplevel builds; both remaining hosts evaluate. The
  complete generated Hyprland Lua configuration passes `--verify-config` in an
  isolated environment.

The Sway tests do not exercise Hyprland-specific dispatch, blur or physical
hardware. Before daily use, validate fingerprint enrollment, native Hyprland lock
recovery and suspend/resume, dock/monitor hotplug, sound and brightness keys, Wi-Fi
credentials, Bluetooth pairing, tray actions and battery alerts on g12. Battery
consumption and before/after closure growth have not been measured.

## Development and rollout

After installation, `quickshell-dev /path/to/repo` previews working-tree QML with
live reload. Before installation, use the development shell and set `QS_SETTINGS`
to the built bundle's `generated.json`, `QS_DEV=1`, `QS_PREVIEW=1`, and a separate
writable `QS_STATE_DIR`, then run `quickshell --path home/files/quickshell/shell.qml`.

Inspect production IPC with `quickshell ipc --config desktop show`, and logs with
`journalctl --user -u quickshell -e`. The generated `hypr/shell_commands.lua`
connects the existing shortcuts to those IPC methods.

When explicitly ready to deploy, switch while unlocked and start a fresh graphical
session so the former startup-hook daemons exit. Keep the previous NixOS generation
for rollback. Never deploy/restart deliberately while locked. If automatic crash
recovery fails, use a TTY to restart the user service; if the compositor cannot
restore the lock, terminate the graphical session and log in again.
