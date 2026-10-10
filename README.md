# nixos-dotfiles

Fully declarative **NixOS + Home Manager** configuration for a Hyprland desktop,
with a self-authored **Quickshell desktop styled from Omarchy's Tokyo Night theme**.
Migrated from an Arch/Hyprland dotfiles setup and
rewritten as pure Nix (no live-symlinked dotfile tree).

**Hosts:**
- `thinkpad-x1-carbon-g12` — ThinkPad X1 Carbon (Gen 12, 21KC; Intel Core Ultra 5
  125U / Meteor Lake, btrfs root). Desktop.
- `homeserver` — Gigabyte H81M-HD2 (i5-4460 Haswell, 16 GB, RTX 3070). Headless
  media server: the Docker Compose stack (Traefik, Jellyfin, *arr, qBittorrent
  behind a PIA WireGuard container, SABnzbd, Homepage, …) runs unchanged on top
  of NixOS-provided Docker + NVIDIA container toolkit.

Every host imports `hosts/common.nix` (role-agnostic system config); graphical
hosts additionally import `hosts/desktop.nix` (Hyprland, greetd, PipeWire,
fonts, laptop peripherals). The `desktop` flag per host in `flake.nix` also
selects the Home Manager profile: `home/home.nix` (full desktop) or
`home/server.nix` (shell + CLI tools only). Each host dir adds its declarative
disk layout (`disko.nix`) and generated `hardware-configuration.nix`. Fresh
installs are one command via **disko + nixos-anywhere** (see
[Install](#install)).

👉 **Already installed?** [COMMANDS.md](COMMANDS.md) is the day-to-day cheat
sheet — rebuild, update, rollback, garbage collection, service debugging.

## What's inside

| Area | Module | Approach |
|------|--------|----------|
| System (boot, nix, network, user, SSH, Docker, …) | `hosts/common.nix` (every host) + `hosts/<host>/configuration.nix` | NixOS options |
| Desktop system (audio, login, fonts, fcitx5, fingerprint, …) | `hosts/desktop.nix` (graphical hosts only) | NixOS options |
| Compositor + keybindings | `home/hyprland.nix` + `home/files/hypr/*.lua` | Lua config (`configType = "lua"`), wired in via `extraConfig` / `extraLuaFiles` |
| Shell (bar, launcher, menus, notifications, OSD, authentication, lock) | `home/quickshell.nix` + `home/files/quickshell/` | Generated JSON + modular QML; systemd user service |
| Idle / wallpaper / night light | `home/desktop.nix` | `services.hypridle` · `services.hyprpaper` · `services.hyprsunset` |
| Terminal | `home/kitty.nix` | Captured Tokyo Night colors, JetBrainsMono Nerd Font 9pt, opacity 0.94 |
| Shell / prompt | `home/shell.nix` | zsh (+fzf, zoxide, eza/bat aliases) + `programs.starship` |
| Independent scripts | `home/scripts.nix` + `home/capture-tools.nix` | Frozen-screen capture, Swappy editing, recording and RSS tools |
| Theme / TUIs | `home/omarchy-palette.nix` + `home/omarchy.nix` | Static desktop palette, btop and VS Code; Superfile/fzf/prompt share the palette |
| Cursor / GTK / icons / Qt | `home/theming.nix` | `home.pointerCursor` · `gtk` · `qt` |

Structured configs are converted to native Nix attribute sets. Opaque blobs that
have no attribute-set form — QML, CSS, kanata `.kbd`, the starship TOML,
shell scripts, images — live under `home/files/` and are referenced from
Nix (`readFile` / `.source` / `importTOML`). That keeps the repo self-contained
and the deployment fully declarative.

**Hyprland is the exception:** its config is Lua
(`home/files/hypr/hyprland.lua` + `keybindings.lua`), because it relies on loops
and local tables — direction maps, workspaces 1..10 — that an attribute set
can't express. `home/hyprland.nix` wires them in and leaves `settings` empty.
Edit the `.lua` files; check them with `luac -p home/files/hypr/*.lua` before
rebuilding, since a parse error leaves Hyprland in a bind-less emergency
session.

```
flake.nix                      # inputs + per-user vars + `hosts` set (with desktop flag) → one config each
hosts/
  common.nix                   # role-agnostic system config (imported by every host)
  desktop.nix                  # desktop-only system config (imported by graphical hosts)
  thinkpad-x1-carbon-g12/
    configuration.nix          # ../common.nix + ../desktop.nix + disko + Meteor Lake iGPU video stack
    disko.nix                  # declarative disk layout (partitioning + fileSystems)
    hardware-configuration.nix # detected hardware only — regenerated at install
  homeserver/
    configuration.nix          # ../common.nix (NO desktop.nix) + headless NVIDIA + server tweaks
    disko.nix                  # declarative disk layout (partitioning + fileSystems)
    hardware-configuration.nix # placeholder — regenerate at install
home/
  home.nix                     # full desktop HM profile (desktop hosts)
  server.nix                   # minimal HM profile: shell + CLI only (headless hosts)
  hyprland.nix  quickshell.nix  kitty.nix  shell.nix
  desktop.nix  scripts.nix  theming.nix
  starship.toml
  files/                       # CSS, rasi, hypr/*.lua, scripts, icons, backgrounds, …
```

## Make it your own

The config is parameterized — to adopt it you don't need to find-and-replace a
username. Edit the two per-user values at the top of the `let` block in
`flake.nix`, then add (or rename) a host in the `hosts` set:

```nix
username = "maxime";       # your login name → home dir becomes /home/<username>
fullName = "Maxime Gagne"; # account description

hosts = {
  "thinkpad-x1-carbon-g12" = { desktop = true; };
  "homeserver" = { desktop = false; };   # headless — no Hyprland, minimal HM profile
  # "<your-hostname>" = { desktop = …; } # ← add yours; create a matching hosts/<your-hostname>/
};
```

Each entry builds `nixosConfigurations.<name>` (via `lib.mapAttrs`), sets
`networking.hostName`, and reads `hosts/<name>/`. `desktop = true` hosts must
import `../desktop.nix` in their `configuration.nix` and get the full
`home/home.nix`; `desktop = false` hosts skip it and get `home/server.nix`. To
add a machine, copy an existing host dir (a laptop for a desktop machine,
`hosts/homeserver` for a headless one), add the entry to the set, adjust its
`disko.nix` (target device + layout), and let the install regenerate its
`hardware-configuration.nix` (see Install below).
`home.homeDirectory`, the NixOS user (`users.users.${username}`), and the flake's
host path all derive from the variables; runtime config paths use `~`, so they
need no edits.

## Install

Installs are driven by **[disko](https://github.com/nix-community/disko)**
(declarative partitioning — each host's layout lives in
`hosts/<hostname>/disko.nix`) and
**[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)**. You boot
the target laptop on the NixOS installer USB, then run **one command from
another machine** — it partitions and formats per the disko layout, generates
the real `hardware-configuration.nix` back into your working tree, installs the
flake, and reboots. No manual `parted`/`mkfs`, no `nixos-enter`.

Commands assume the **Gen 12** (`thinkpad-x1-carbon-g12`).

> ⚠️ **The install erases the device named in `hosts/$HOST/disko.nix`**
> (`/dev/nvme0n1`). Confirm with `lsblk` on the target — the disko layout, not
> an interactive prompt, decides what gets wiped.

### 0. Make NixOS install media

Download the **Minimal ISO** (x86_64) from <https://nixos.org/download/> — direct
link `https://channels.nixos.org/nixos-26.05/latest-nixos-minimal-x86_64-linux.iso`
(the Graphical ISO works too). Verify the SHA-256 shown on the download page, then
write it to a USB stick — replace `/dev/sdX` with the **stick's** device (not a
partition, and not your internal disk):

```sh
sudo dd if=nixos-minimal-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Reboot, tap **F12** for the ThinkPad boot menu (or **F1** for firmware), and boot
the USB. If it refuses, disable **Secure Boot** in firmware first.

### 1. Get online (in the installer)

NetworkManager is running; connect Wi-Fi from the console with `nmtui` (works in a
non-graphical session):

```sh
sudo nmtui            # Activate a connection → choose your SSID → enter password
ping -c1 nixos.org    # confirm connectivity
```

### 2. Let the other machine SSH in (on the target)

The installer logs in as the `nixos` user, which has no password and so can't be
SSH'd into yet — set one, then note the laptop's IP:

```sh
passwd                # set a password for the 'nixos' user (sshd is already running)
ip -c a               # note the wlan IP, e.g. 192.168.2.31
```

That's everything on the target. The rest runs from your other machine.

### 3. Run nixos-anywhere (from your other machine)

Any Linux/macOS box with Nix will do (flakes enabled — if not, prefix the
commands with `NIX_CONFIG="experimental-features = nix-command flakes"`, or pass
`nix --extra-experimental-features "nix-command flakes" run …`; a NixOS installer
ISO ships with flakes **off**, so from one of those you always need this).

> ⚠️ **Don't drive this from a second NixOS live USB.** The installer's Nix store
> is a tmpfs sized at ~half RAM, and this flake's closure (LibreOffice, browsers,
> fonts) does not fit. It dies partway through with
> `error: write of N bytes: No space left on device`. Either use a real installed
> machine, or add `--build-on-remote` so the target builds its own closure onto
> its disk instead of the helper's RAM. With no real second machine, skip to
> [Install from the target itself](#install-from-the-target-itself) — it's the
> more reliable route.

```sh
git clone https://github.com/max8989/nixos-dotfiles
cd nixos-dotfiles
```

Review before installing:

- `hosts/$HOST/disko.nix` → the `device` that will be **erased** (default
  `/dev/nvme0n1` — check against `lsblk` on the target).
- `system.stateVersion` (`hosts/common.nix`) **and** `home.stateVersion`
  (`home/home.nix`) → preset to `26.05`. Only change these if you install a
  different release, and never bump them after install.
- `time.timeZone` (currently `America/Toronto`) and `i18n.defaultLocale`.

Then install:

```sh
HOST=thinkpad-x1-carbon-g12

nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config ./hosts/$HOST/hardware-configuration.nix \
  --flake .#$HOST \
  --target-host nixos@<IP>
```

One command does all of it: SSHes to the installer (it detects the NixOS
installer and skips its kexec step), partitions + formats per
`hosts/$HOST/disko.nix`, regenerates `hosts/$HOST/hardware-configuration.nix`
in your working tree (with `--no-filesystems` — disko owns the filesystems),
builds and installs the flake, and reboots into the new system.

Afterwards, commit the regenerated hardware config so the repo matches the
machine:

```sh
git add hosts/$HOST/hardware-configuration.nix
git commit -m "hardware config for $HOST"
git push
```

### Install from the target itself

No second machine needed — run everything on the ThinkPad booted from the
installer USB (over SSH from anywhere, or at its own console). This is the route
that was actually used for the Gen 12, and it's more robust than
`disko-install`: **`disko-install` builds the closure into the installer's tmpfs
store before it ever touches the disk**, so on a 16 GB machine it fills RAM and
dies. Splitting it in two avoids that, because `nixos-install` passes
`--store /mnt` and downloads straight onto the freshly-mounted disk.

```sh
HOST=thinkpad-x1-carbon-g12
git clone https://github.com/max8989/nixos-dotfiles ~/nixos-dotfiles
cd ~/nixos-dotfiles

# 1. Real hardware config (no filesystems — disko owns those)
sudo nixos-generate-config --no-filesystems --show-hardware-config \
  > hosts/$HOST/hardware-configuration.nix

# 2. Partition + format + mount at /mnt
sudo nix --extra-experimental-features "nix-command flakes" \
  run 'github:nix-community/disko/latest#disko' -- \
  --mode destroy,format,mount --yes-wipe-all-disks \
  --flake "path:$PWD#$HOST"

# 3. Build + install onto the disk (this is the long one)
sudo NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-install --root /mnt --flake "path:$PWD#$HOST" --no-root-passwd

sudo reboot
```

Notes:

- **Use `path:$PWD#$HOST`, not `.#$HOST`.** The `path:` ref copies the directory
  as-is, so the `hardware-configuration.nix` you just regenerated is picked up
  without a `git add` (plain `.#` only sees git-tracked files, and errors under
  `sudo` on a repo owned by another user).
- `--no-root-passwd` leaves root locked, which is correct here: your account is
  in `wheel` and gets in via `sudo`, and it logs in first with
  `initialPassword = "changeme"`.
- Run step 3 under `screen`, or detached with
  `sudo setsid nohup … >/tmp/nixos-install.log 2>&1 &`, so a dropped SSH session
  doesn't kill the install partway through.
- If the installer's tmpfs fills anyway, reclaim it with `sudo nix-collect-garbage`
  — but **do not reboot** the installer to clean it: the `nixos` password and
  your authorized SSH key live on that tmpfs and are lost, which costs you
  physical access to the machine.

#### Reinstalling over an existing Linux install

A previous install's signatures can survive disko's wipe and resurface at the
same offset in the new partition, so the mount fails with
`unknown filesystem type 'LVM2_member'` (or `crypto_LUKS`, `zfs_member`, …) even
though disko just made a btrfs filesystem there. Scrub the disk once before
step 2 above and it won't come back:

```sh
sudo umount -R /mnt 2>/dev/null
sudo vgchange -an; sudo dmsetup remove_all      # tear down any active LVM
sudo wipefs -af /dev/nvme0n1p*                  # per-partition signatures
sudo wipefs -af /dev/nvme0n1                    # GPT/PMBR
sudo sgdisk --zap-all /dev/nvme0n1
sudo blkdiscard -f /dev/nvme0n1                 # full SSD trim
```

`sudo wipefs /dev/nvme0n1` should then print nothing.

### 4. First boot

Remove the USB. Log in at **tuigreet → Hyprland** as your user with the
first-boot password **`changeme`** (seeded via `initialPassword` in
`hosts/common.nix`, since neither install route has an interactive password
step) — then **immediately** change it and enroll the fingerprint reader:

```sh
passwd
fprintd-enroll
```

### Where the repo lives after install

Clone the repo on the new machine and rebuild from there — flakes build from
**any** path, the location is not special:

```sh
git clone https://github.com/max8989/nixos-dotfiles ~/repos/nixos-dotfiles
cd ~/repos/nixos-dotfiles
```

If you pushed the regenerated `hardware-configuration.nix` in step 3 it's
already here; otherwise copy/commit it before the first rebuild. Pick one home
for the repo and rebuild from it consistently (the examples below use
`~/repos/nixos-dotfiles`). The only hard rule is that the flake can only see
**git-tracked** files inside the repo, so `git add` new files before rebuilding.

### Rebuild after changes

```sh
cd ~/repos/nixos-dotfiles
nix flake check                                              # evaluate both hosts first
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
```

`switch` builds the new generation and activates it immediately. Use
`boot` instead of `switch` to apply only on next reboot, or `test` to activate
without making it the boot default.

### (Optional) test in a VM first

```sh
nix build .#nixosConfigurations.thinkpad-x1-carbon-g12.config.system.build.vm
./result/bin/run-thinkpad-x1-carbon-g12-vm
```

## Adding or changing packages

Where a package goes depends on what it is. Find the binary you want first
(`nix search nixpkgs <name>` or <https://search.nixos.org/packages>), then add the
**attribute name** to the right list:

| What you're adding | Where | How |
|--------------------|-------|-----|
| A user app or CLI tool (browsers, editors, `ripgrep`, …) | `home/home.nix` → `home.packages` | add the attr to the list |
| A system service / daemon (docker, flatpak, firewall, printing, …) | `hosts/common.nix` | use its NixOS option, e.g. `services.<name>.enable = true;` |
| A font | `hosts/common.nix` → `fonts.packages` | add the attr to the list |
| Something only one machine needs (GPU drivers, kernel modules) | `hosts/<host>/configuration.nix` | per-host option |

Most of the time you want the first row. For example, to add `neofetch`:

```nix
# home/home.nix — inside home.packages = with pkgs; [ … ];
home.packages = with pkgs; [
  # …existing…
  neofetch
];
```

Then evaluate and apply:

```sh
cd ~/repos/nixos-dotfiles
nix flake check                                             # catch typos/renamed attrs early
nixfmt **/*.nix                                             # keep formatting consistent
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
```

Notes:

- **Unfree packages** (Chrome, Spotify, VS Code, …) already work — `common.nix`
  sets `nixpkgs.config.allowUnfree = true;`.
- **No native package?** Check if it's on Flathub — `services.flatpak` is enabled
  (add a remote once: `flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo`),
  or for browser-launched binaries see the zen-browser flake input as a model.
- Don't `pip install` / `npm -g` / drop binaries in `~/.local/bin` and expect them
  to persist — on NixOS the declarative list is the source of truth.

## Verify on first build

`nix flake check` now passes clean on both hosts against the pinned `flake.lock`,
so the attribute/option names below are confirmed present there. They're kept as
a checklist for when you bump `nixpkgs`/`home-manager` (re-run `nix flake check`
after any input update and fix anything that has since moved):

- `pkgs.gnome-themes-extra`, `pkgs.yaru-theme`, `pkgs.catppuccin-kvantum`.
- `pkgs.figtree` — may live under `google-fonts`.
- `pkgs.nerd-fonts.caskaydia-cove` / `pkgs.nerd-fonts.jetbrains-mono` (post nerd-fonts restructure).
- `pkgs.zed-editor`, `pkgs.quickshell` (currently 0.3.1).
- `i18n.inputMethod.type = "fcitx5"` (newer form; older nixpkgs used `enabled = "fcitx5"`).
- HM service modules used here: `services.hypridle`, `services.hyprpaper`,
  `services.hyprsunset`, `programs.quickshell`.
- `inputs.zen-browser.packages.<system>.default`.
- Captured Kitty settings and `programs.btop.themes`.
- `wayland.windowManager.hyprland.configType` — defaults to `"lua"` from
  `home.stateVersion` 26.05 (it was `"hyprlang"` before). The Lua backend also
  provides `extraLuaFiles` / `extraConfig`, both used here.

## Known gaps / deviations from the Arch setup

- **Static Omarchy appearance.** The desktop uses the effective Tokyo Night
  theme from the Omarchy 4.0.0.alpha snapshot captured 2026-10-10. Nix generates
  shell surface tokens, app settings and executable paths; a rebuild changes
  the theme. The headless profile retains its original Jade CLI palette.
  GTK uses dark Adwaita and Yaru-magenta icons; Qt retains its working Kvantum
  integration, recolored to Tokyo Night. Snapshot assets and license notices
  live in `home/files/omarchy/`.
- **Retained desktop features.** The transparent 26px top bar keeps reminders,
  status indicators, tray controls and existing responsive visibility rules.
  The shell source and wallpaper images were absent from the snapshot, so
  Quickshell is restyled with its captured tokens and the existing wallpaper
  is retained. Kitty is the only migrated terminal; Swappy handles editing.
- **Alt-Tab is `hyprshell`, not `hyprswitch`.** Upstream renamed the project and
  changed the CLI, so the Arch binds/`exec-once` were dropped. The switcher is
  back as `services.hyprshell` in `home/desktop.nix` — a Home Manager systemd
  user service that registers ALT+TAB itself via Hyprland's global-shortcuts
  protocol, so there is no bind in `keybindings.lua`. Hold ALT, tap TAB
  (SHIFT+TAB or grave to go backwards), release ALT to focus. The SUPER overview
  / launcher half of hyprshell is left off.
- **Audio output selection** (SUPER+F12 / bar click) uses Quickshell's native PipeWire service.
- **Night light** uses the retained hyprsunset daemon, controlled by Quickshell. Preferences persist outside the Nix store.
- **Daemon autostart** is managed by Home Manager systemd user units. Quickshell provides notifications, polkit prompts, tray hosting, menus, OSD, and locking. Cliphist capture remains in the compositor startup hook.
- **Neovim is managed separately.** Its configuration and explicit theme remain
  owned by the user's `nvim-config` repository.

## Screenshot workflow

Alt+1 selects a region, Alt+2 picks a window, Alt+3 captures the focused monitor,
and Print uses smart selection. Interactive captures freeze the displayed
content. While the picker is open, Tab/Ctrl+Tab or arrows change the highlighted
window; Enter captures it and Ctrl+Enter captures the focused monitor. Escape
cancels, and pressing a screenshot shortcut again cancels the active picker.
These temporary bindings disappear after the last selection layer closes.

Captures are saved under `~/Pictures/Screenshots`, copied as PNG images, and
shown in a preview notification with an Edit action. Super+Alt+comma opens the
latest saved capture in Swappy. The capture menu offers the same actions.
Alt+4 retains the existing focused-monitor recording toggle.

The packaged `nixos-screenshot` helper accepts
`[smart|region|windows|fullscreen] [slurp|copy|save]`: the default `slurp` processing
saves, copies and notifies; `copy` only updates the image clipboard; `save` only
writes a file. Successful saved captures print their path. Set
`NIXOS_SCREENSHOT_DIR` to override the output directory. Cancellation preserves
the clipboard; failed captures remove partial files and restore cursor state.

## Quickshell development and validation

The immutable bundle contains QML and one Nix-generated JSON. Palette, layout,
user paths and executable paths belong in `home/quickshell.nix` and captured
surface tokens in `home/omarchy-shell-style.nix`; QML owns the
views and live service state. Preferences live in
`$XDG_STATE_HOME/quickshell-desktop/`. The retired g7 host and GTK shell configs
have been removed; the homeserver keeps its headless profile.

```sh
nix develop .#quickshell
nix build .#quickshell-config --no-link
nix flake check
nix build .#quickshell-vm-test --no-link
nix build .#nixosConfigurations.thinkpad-x1-carbon-g12.config.system.build.toplevel --no-link
```

After installation, run `quickshell-dev /path/to/nixos-dotfiles` to preview the
working tree with live reload and separate preferences. It puts the bar at the
bottom and does not register notifications, a tray host, polkit, or a session
lock. The packaged service has file watching disabled and restarts when its
bundle's store path changes. A preview is also available before installation:
build the bundle, set `QS_SETTINGS` to its `generated.json`, set `QS_PREVIEW=1`
and `QS_DEV=1`, and run `quickshell --path home/files/quickshell/shell.qml` from
the development shell. Give `QS_STATE_DIR` a separate writable directory.

The developer shell includes Sway, grim and wtype for the isolated UI harness:

```sh
python3 tests/quickshell-smoke.py /nix/store/…-quickshell-desktop /tmp/quickshell-smoke
```

The harness uses its own compositor, D-Bus session, clipboard cache and fixture
files. Screenshots and results are written to the supplied directory. The VM
test exercises real PAM password authentication, rejection, notifications, and
the compositor's fail-closed session lock. Test passwords exist only in the VM.
`nix flake check` also exercises capture cancellation, PNG clipboard data,
selection geometry, overlapping/hidden windows, scaled/rotated monitors,
failure cleanup, and the lifetime of temporary selection bindings.

Inspect actions with `quickshell ipc --config desktop show`. Examples:

```sh
quickshell ipc --config desktop call menus toggle controls
quickshell ipc --config desktop call menus toggle audio
quickshell ipc --config desktop call display nightlight
quickshell ipc --config desktop call session lock
journalctl --user -u quickshell -e
```

**Super+M** opens Desktop controls. Type to search across actions (for example
`volume`, `dnd`, `wifi` or `restart`), use Up/Down to select, and Enter to open
or toggle. Left/Right adjusts volume, microphone level, brightness and night
light temperature; Enter on a sound level toggles mute. Escape or Alt+Left
returns to the previous menu, restoring its search and selection; Escape at
the root closes it. Ctrl+L focuses and selects the search text.

The four settings panels open beside the top bar and are also available from
Super+M or their bar icons:

| Shortcut | Panel | Controls |
|---|---|---|
| Super+Ctrl+A | Audio | Output/input volume, mute, device selection and optional live microphone test |
| Super+Ctrl+W | Wi-Fi | Radio, saved/available networks, password entry, traffic, IP/gateway, DHCP/Cloudflare/Google DNS |
| Super+Ctrl+D | Display | Laptop brightness, panel text size, per-monitor scale, night light, keep awake |
| Super+Ctrl+P | Battery | Charge, capacity, health, cycles, charge limit and power profiles |

Use Tab/Shift+Tab to move, Left/Right on sliders, and Enter/Space to select.
The night-light bar icon opens Display; right-click still toggles night light.
Scale changes revert after 15 seconds unless confirmed, or when the panel closes.
Confirmed scales follow the display description and are restored after login,
monitor reconnection and Hyprland configuration reload. DNS presets update the
active saved connection and roll back its settings if NetworkManager rejects
the change. Custom DNS and hidden networks open in nmtui. Battery charge limits
are displayed as reported by the kernel; this panel does not change thresholds.
Panel text size applies to these four panels. Use monitor scale to resize apps.

The menu also includes calendar, reminders, workspaces, media, clipboard,
capture, system status and tray application menus. Tab/Shift+Tab and
Enter/Space operate notification actions and confirmations. Calendar uses
Left/Right for months and Home for today. Restart, shutdown, logout and
hibernate require confirmation, with Cancel focused initially. Settings
entries open source files under `settings.paths.dotfiles` (configured in
`home/quickshell.nix`); Nix-managed changes need a rebuild.

Do not restart or deploy the shell while locked. The recovery marker is scoped
to the compositor instance, and Hyprland is configured to allow lock restoration
after a crash. If recovery fails, use a TTY to restart the user service; if the
compositor cannot restore the lock, terminate that graphical session and log in
again. Never disable the lock to recover it.

The implementation is build-only until explicitly activated. For the first
rollout, switch while unlocked and start a fresh graphical session so previously
running startup-hook daemons exit. Retain the previous NixOS generation for
rollback. Physical fingerprint enrollment, suspend/resume, dock hotplug,
Bluetooth pairing and device-specific battery/brightness behavior require a
live acceptance pass. See `HANDOFF-quickshell.md` for current verification.
