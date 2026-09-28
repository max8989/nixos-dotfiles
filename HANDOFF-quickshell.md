# Handoff — custom Quickshell desktop

**Updated:** 2026-09-28
**Status:** The tooltip, interaction and clipboard follow-up bundle is installed
on `thinkpad-x1-carbon-g12`. The user service is active; all changed QML/JS files
match the installed bundle (verified after the 10:37 EDT service restart).

## Decisions and scope

- Full shell: bar, menus, OSD, notifications, tray, polkit and session locking.
- Keep the neon glass palette, Chinese lock content and existing keyboard shortcuts.
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

Preferences live under `$XDG_STATE_HOME/quickshell/desktop` (falling back to
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
