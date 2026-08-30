# Handoff — Quickshell evaluation (replace the waybar/GTK shell stack?)

**Date:** 2026-08-28
**Trigger:** "Is upgrading to Quickshell a good choice — the same one Omarchy uses?"
**Status:** Evaluated. **Decision taken: build our own shell, not adopt someone else's
config.** Nothing implemented, nothing changed in the flake. Design below; four
decisions open.

---

## 1. The question

<https://quickshell.org/> — a QtQuick/QML desktop-shell **toolkit**. Should this repo
replace the current stack (waybar + wofi/rofi + swaync + swayosd + wlogout + hyprlock
+ ~20 bash scripts) with a single self-authored Quickshell instance?

Constraint stated up front: **no dependency on a third party's shell config.** Our own
code, but it has to be *less* to maintain than what we have now — not more.

## 2. What was verified (2026-08-27/28)

| claim | evidence |
|---|---|
| Omarchy really did move to Quickshell | `basecamp/omarchy` master, `version` = **`4.0.0.alpha`**. `install/omarchy-base.packages:112` = `quickshell`. **No** waybar / walker / mako / swayosd / wofi anywhere in the package lists. |
| …and it's a full rewrite, not a bar swap | `docs/omarchy-shell.md`: "a single long-running Quickshell instance that hosts the Omarchy desktop. The bar, panels, overlays, menus, and services all run inside as plugins." `shell/` = 2.0 MB, **104 `.qml` files**, plugin manifests, IPC. |
| Omarchy 3.x (what most people run) still uses Waybar | waybar only survives in 7 files on master, mostly the `omarchy-upgrade-to-quattro` migration path and doc/QML references. |
| Quickshell is packaged for us | `nixpkgs` (our `nixos-unstable` pin) evaluates `quickshell` **0.3.0**; upstream released **0.3.1 on 2026-08-20**. Qt6 (`qtbase`/`qtdeclarative`/`qtwayland`/`qtsvg`) + wayland + pipewire + pam + polkit. `meta.mainProgram = "quickshell"`. |
| Home Manager has a real module | `programs.quickshell`: `enable`, `package` (nullable), `configs` (attrset name→path, lands at `~/.config/quickshell/<name>`, names must not contain `/`), `activeConfig`, `systemd.enable`, `systemd.target` (defaults to `config.wayland.systemd.target`). Generated unit: `ExecStart = <pkg> --config <activeConfig>`, `Restart = on-failure`, `WantedBy = <target>`. |

## 3. Verdict

**Quickshell is a toolkit, not a config — "upgrading" to it means writing a shell in
QML.** That is the whole cost, and it is real: expect roughly a weekend to reach
waybar parity, on a 0.x API that will break across releases.

In steady state it is still the better deal for this repo: one process, one language,
typed service APIs, an actual LSP, and the entire bash-glue layer deleted. Two things
keep that from being wishful thinking — the layering in §4 (so the config doesn't
degrade into blobs) and the staged migration in §8 (so we're never mid-rewrite with a
broken desktop).

**Rejected:** adopting `caelestia-dots/shell` or `AvengeMedia/DankMaterialShell`. Both
ship first-class Nix flakes + HM modules (`programs.caelestia`,
`homeModules.dank-material-shell`) and would have been the cheap path, but they are
someone else's config — explicitly out of scope.

**Also rejected:** porting `omarchy-shell` itself. It is coupled to the `omarchy-*`
CLIs, its own theme system, and a plugin model that git-clones into
`~/.config/omarchy/plugins/` — the same read-only-store fight we already hit with
hyprshell's `config.json`. And it is `4.0.0.alpha`.

## 4. Architecture — Nix owns the data, QML owns the view

This is what keeps the repo's two-tier rule intact instead of dumping a shell's worth
of blobs into `home/files/`.

`home/quickshell.nix` emits **one generated JSON** — palette, module toggles, bar
layout, and every absolute store path — and the QML reads it. This generalizes the
existing `@polkitAgent@` substitution in `home/hyprland.nix` instead of scattering
`builtins.replaceStrings` calls.

```nix
# home/quickshell.nix
{ config, pkgs, ... }:
let
  settings = {
    theme = { base = "#1e1e2e"; text = "#cdd6f4"; accent = "#89b4fa"; };
    bar = { position = "top"; margin = 6; center = [ "clock" "todos" ]; };
    bin = {                                  # store paths, never hard-coded in QML
      hyprsunset = "${pkgs.hyprsunset}/bin/hyprsunset";
      wpctl = "${pkgs.wireplumber}/bin/wpctl";
    };
  };
in
{
  programs.quickshell = {
    enable = true;
    configs.bar = ./files/quickshell;   # -> ~/.config/quickshell/bar
    activeConfig = "bar";
    systemd.enable = true;             # graphical-session.target, Restart=on-failure
  };

  xdg.configFile."quickshell/bar/generated.json".text = builtins.toJSON settings;
}
```

Read side — `FileView` + `JsonAdapter` from `Quickshell.Io`; each adapter property is a
JSON key and carries its own default, so QML holds the schema:

```qml
// Config.qml — the only file that knows Nix exists
pragma Singleton
import Quickshell
import Quickshell.Io
Singleton {
  FileView {
    path: Qt.resolvedUrl("./generated.json")
    blockLoading: true                  // loaded before first use
    JsonAdapter {
      property var theme: ({})
      property var bar: ({})
      property var bin: ({})
    }
  }
}
```

**Runtime state the shell mutates itself** (nightlight on/off, bar hidden, last audio
sink) goes in a *second* JSON under `~/.local/state`, written with
`FileView.writeAdapter()` on `onAdapterUpdated`. Never into the store copy — it is
read-only, and that is exactly the hyprshell failure mode.

Layout:

```
home/files/quickshell/
  shell.qml            # ShellRoot -> Variants over Quickshell.screens
  Config.qml           # singleton above
  bar/Bar.qml
  bar/widgets/{Clock,Cpu,Memory,Network,Audio,Mic,Nightlight,Battery}.qml
  panels/  osd/  lock/  notifications/
```

Two rules that decide whether this stays maintainable:

- **No `root:/` imports.** The Quickshell docs warn they break the LSP and singletons
  ("a replacement without these issues is planned"). Use directory imports +
  `pragma Singleton`.
- Follow them and `qmlls` type-checks the whole shell in the editor — strictly better
  than today's JSON + bash, where nothing is checked until runtime.

## 5. What gets deleted

Every row below is a **built-in Quickshell module** (verified against the v0.3.0 module
listing), not something we'd script:

| today | becomes |
|---|---|
| `volume-control.sh`, `audio-menu.sh`, `mic-status.sh` | `Quickshell.Services.Pipewire` |
| `wifi-status.sh`, `wifi-menu.sh` | `Quickshell.Networking` |
| `bluetooth-menu.sh` | `Quickshell.Bluetooth` |
| `battery-level.sh`, `battery-state.sh` | `Quickshell.Services.UPower` |
| swaync + `custom/notification` | `Quickshell.Services.Notifications` (we *are* the daemon) |
| swayosd + `brightness-control.sh` | our own OSD window |
| `power-menu.sh`, `todo-menu.sh`, `rofi-anchor.sh`, wlogout | plain QML popups — no rofi, no anchoring hacks |
| hyprlock | `Quickshell.Wayland` `WlSessionLock` + `Quickshell.Services.Pam` |
| polkit agent in the `hyprland.start` hook | `Quickshell.Services.Polkit` |
| `whatsong.sh` | `Quickshell.Services.Mpris` |
| tray | `Quickshell.Services.SystemTray` + `Quickshell.DBusMenu` |
| `hyprland/workspaces`, `hyprland/window` | `Quickshell.Hyprland` |

`cpu-info.sh`, `memory-info.sh`, `cpu-temp.sh`, `todos.sh` stay ours — but as a
`FileView` on `/proc` plus a `Timer` **inside the process**, not a fork per second.

**Keybinds stop being script-per-action.** Define
`IpcHandler { target: "bar"; function toggleNightlight(): void { … } }` and call
`qs ipc call bar toggleNightlight` from `keybindings.lua`; `qs ipc show` lists the
registered targets. That also retires the whole `#!/usr/bin/env bash` failure class
documented in `CLAUDE.md`.

## 6. Dev loop (the thing that decides if this is bearable on NixOS)

Quickshell live-reloads on save — but a store symlink never changes on save, so under
Home Manager that feature dies. Keep two paths:

- **iterate:** `qs -p ~/repos/nixos-dotfiles/home/files/quickshell/shell.qml` straight
  from the working tree → reload on save, no rebuild. (Alternative: a second
  `configs.dev = config.lib.file.mkOutOfStoreSymlink …` entry pointing at the repo.)
- **promote:** rebuild; the store copy is what the systemd service runs.

## 7. Ops / risk controls

- **Run it as the HM systemd user service, not from the `hyprland.start` hook.**
  `programs.quickshell.systemd.enable` already generates the right unit
  (`Restart=on-failure`, wanted by `graphical-session.target`). Omarchy's own docs
  record why this matters: Qt leaves through `_exit()` when the Wayland connection
  fails, **raising no signal — no crash report, no relaunch, no bar**. An `exec-once`
  gives us nothing back. Same reasoning as the kanata unit.
- **Journal the logs.** Quickshell only logs to its instance runtime dir (tmpfs), so
  the crash trail is gone after a reboot. Omarchy wraps the launch in `systemd-cat`.
- **Disable/ignore Quickshell's own auto-reload for the store config.** Omarchy turns
  it off deliberately: a reload against a half-written tree leaves a second engine
  generation behind, and the *next* restart then crashes. A `nixos-rebuild` swapping
  the store path is exactly that half-written-tree case.
- **Add a syntax gate** — the QML analogue of the repo's `luac -p` rule — running
  `qmllint` over `home/files/quickshell/` in `nix flake check`. A parse error in the
  shell is as bad as a parse error in `hyprland.lua`.
- **Single failure domain.** Bar + notifications + OSD + launcher + lock in one
  process. Mitigated by `Restart=on-failure`, but it is strictly more centralized than
  today's four daemons — accept it knowingly.
- **0.x API.** `nixpkgs` 0.3.0 vs upstream 0.3.1; breaking changes between minors are
  expected. Pin deliberately and read release notes before bumping.

## 8. Migration order (parity gates — delete nothing early)

1. `home/quickshell.nix` + generated JSON + minimal bar (workspaces, clock, battery),
   running **alongside** waybar for side-by-side comparison.
2. Bar to full parity (cpu, memory, network, audio, mic, nightlight, idle inhibitor,
   power profiles, tray, todos). → then drop `waybar.nix` + `files/waybar/`.
3. OSD → drop swayosd. 4. Notifications → drop swaync. 5. Launcher/menus → drop
   wofi/rofi/wlogout. 6. Lock → drop hyprlock.

`waybar.nix` stays in tree until step 2 passes. Each step is one commit that can be
reverted on its own.

## 9. Open decisions

1. **Which host first.** g12 (Meteor Lake, daily driver) or g7 as a crash-test box?
   The flake builds both, so a `quickshell.nix` imported by only one host means a
   host-specific `home.nix` import list — currently both hosts share one.
2. **How far to go.** Bar-only (keep swaync/swayosd/wofi/hyprlock) is a perfectly
   stable end state and ~⅓ of the work. Full shell is where the "one coherent thing"
   payoff is. Steps 3–6 are optional and independently revertable either way.
3. **Theme source of truth.** Mocha hex values are currently spread across
   `waybar/style.css`, `wofi`, `rofi/*.rasi`, hyprlock. Do we lift the palette into a
   Nix attrset in `theming.nix` and feed both the generated JSON *and* the remaining
   CSS from it, or leave the legacy blobs alone until their tool is deleted?
4. **Version pin.** Track `nixpkgs` (0.3.0, moves when we bump the lock) or add
   `quickshell` as its own flake input for 0.3.1+ and pin it independently?

## 10. Unverified — check before relying on

- **Closure size.** Not measurable locally (`quickshell` isn't built in this store).
  Expect a Qt6 closure broadly comparable to the GTK stack already present; not
  measured, so don't quote a number.
- **`qs` binary.** The docs' CLI is `qs` (`qs ipc call`, `qs -p`), but the nixpkgs
  package's `meta.mainProgram` is `quickshell`. Confirm both binaries are installed
  before writing `qs …` into keybinds.
- **`qmllint`** — assumed to ship with `qt6.qtdeclarative`; confirm the binary is
  exposed before wiring the flake check.
- **Battery cost.** A continuously-rendering QtQuick scene graph vs a GTK bar is
  nonzero but unquantified. The docs' own hint — `SystemClock.precision: Minutes`
  when seconds aren't displayed — suggests it is worth being deliberate about.

## 11. Next step

Scaffold step 1: `home/quickshell.nix` with the generated-JSON plumbing, `Config.qml`,
and a minimal bar (workspaces, clock, battery) alongside waybar. Roughly one file of
Nix and four small QML files; `nix flake check` must pass and waybar must be untouched.
