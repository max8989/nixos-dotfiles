# nixos-dotfiles

Fully declarative **NixOS + Home Manager** configuration for a Hyprland desktop,
themed **Catppuccin Mocha**. Migrated from an Arch/Hyprland dotfiles setup and
rewritten as pure Nix (no live-symlinked dotfile tree).

**Hosts:**
- `thinkpad-x1-carbon-g7` — ThinkPad X1 Carbon (7th Gen).
- `thinkpad-x1-carbon-g12` — ThinkPad X1 Carbon (Gen 12, 21KC; Intel Core Ultra 5
  125U / Meteor Lake, btrfs root).

Both hosts share one system module (`hosts/common.nix`) and the same Home Manager
config; each only adds its own declarative disk layout (`disko.nix`) and
generated `hardware-configuration.nix` (plus, for the Gen 12, the Meteor Lake
iGPU video stack). Fresh installs are one command via **disko + nixos-anywhere**
(see [Install](#install)).

👉 **Already installed?** [COMMANDS.md](COMMANDS.md) is the day-to-day cheat
sheet — rebuild, update, rollback, garbage collection, service debugging.

## What's inside

| Area | Module | Approach |
|------|--------|----------|
| System (boot, audio, login, fonts, fcitx5, fingerprint, …) | `hosts/common.nix` (shared) + `hosts/<host>/configuration.nix` | NixOS options |
| Compositor + keybindings | `home/hyprland.nix` + `home/files/hypr/*.lua` | Lua config (`configType = "lua"`), wired in via `extraConfig` / `extraLuaFiles` |
| Status bar | `home/waybar.nix` | `programs.waybar.settings` + `readFile style.css` |
| Lock / idle / wallpaper | `home/desktop.nix` | `programs.hyprlock` · `services.hypridle` · `services.hyprpaper` |
| Launcher / menus / OSD | `home/desktop.nix` | `programs.wofi` + rofi/wlogout/swayosd files |
| Terminal | `home/kitty.nix` | `programs.kitty` (+ `themeFile = "Catppuccin-Mocha"`) |
| Shell / prompt | `home/shell.nix` | zsh (+fzf, zoxide, eza/bat aliases) + `programs.starship` |
| Scripts + timers | `home/scripts.nix` | in-repo scripts + systemd user timers |
| Cursor / GTK / icons / Qt | `home/theming.nix` | `home.pointerCursor` · `gtk` · `qt` |

Structured configs are converted to native Nix attribute sets. Opaque blobs that
have no attribute-set form — CSS, rofi `.rasi`, kanata `.kbd`, the starship TOML,
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
flake.nix                      # inputs + per-user vars + `hosts` list → one config each
hosts/
  common.nix                   # shared system config (imported by every host)
  thinkpad-x1-carbon-g7/
    configuration.nix          # imports ../common.nix + disko + hardware
    disko.nix                  # declarative disk layout (partitioning + fileSystems)
    hardware-configuration.nix # detected hardware only — regenerated at install
  thinkpad-x1-carbon-g12/
    configuration.nix          # ../common.nix + disko + Meteor Lake iGPU video stack
    disko.nix                  # declarative disk layout (partitioning + fileSystems)
    hardware-configuration.nix # detected hardware only — regenerated at install
home/
  home.nix  hyprland.nix  waybar.nix  kitty.nix  shell.nix
  desktop.nix  scripts.nix  theming.nix
  starship.toml
  files/                       # CSS, rasi, hypr/*.lua, scripts, icons, backgrounds, …
```

## Make it your own

The config is parameterized — to adopt it you don't need to find-and-replace a
username. Edit the two per-user values at the top of the `let` block in
`flake.nix`, then add (or rename) a host in the `hosts` list:

```nix
username = "maxime";       # your login name → home dir becomes /home/<username>
fullName = "Maxime Gagne"; # account description

hosts = [
  "thinkpad-x1-carbon-g7"
  "thinkpad-x1-carbon-g12"
  # "<your-hostname>"      # ← add yours; create a matching hosts/<your-hostname>/
];
```

Each entry builds `nixosConfigurations.<name>` (via `lib.genAttrs`), sets
`networking.hostName`, and reads `hosts/<name>/`. To add a machine, copy an
existing host dir (e.g. `cp -r hosts/thinkpad-x1-carbon-g7 hosts/<name>`), add the
name to the list, adjust its `disko.nix` (target device + layout), and let the
install regenerate its `hardware-configuration.nix` (see Install below).
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

Commands assume the **Gen 12** (`thinkpad-x1-carbon-g12`); set
`HOST=thinkpad-x1-carbon-g7` for the 7th Gen.

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
HOST=thinkpad-x1-carbon-g12        # or: thinkpad-x1-carbon-g7

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
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12   # or .#thinkpad-x1-carbon-g7
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
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12  # or -g7
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

- `pkgs.catppuccin-gtk` — recent nixpkgs may expose it as `pkgs.catppuccin.gtkTheme`.
- `pkgs.figtree` — may live under `google-fonts`.
- `pkgs.nerd-fonts.caskaydia-cove` / `pkgs.nerd-fonts.jetbrains-mono` (post nerd-fonts restructure).
- `pkgs.zed-editor`, `pkgs.swayosd`, `pkgs.swaynotificationcenter`.
- `i18n.inputMethod.type = "fcitx5"` (newer form; older nixpkgs used `enabled = "fcitx5"`).
- HM service modules used here: `services.hypridle`, `services.hyprpaper`,
  `programs.hyprlock`, `programs.wofi`, `programs.waybar.systemd`.
- `inputs.zen-browser.packages.<system>.default`.
- `programs.kitty.themeFile = "Catppuccin-Mocha"` (name from `pkgs.kitty-themes`).
- `wayland.windowManager.hyprland.configType` — defaults to `"lua"` from
  `home.stateVersion` 26.05 (it was `"hyprlang"` before). The Lua backend also
  provides `extraLuaFiles` / `extraConfig`, both used here.

## Known gaps / deviations from the Arch setup

- **Single theme.** The Arch setup had a runtime 6-theme switcher (it copied
  config files into place). Pure Nix puts configs in the immutable store, so the
  switcher is dropped — **Catppuccin Mocha** is baked in declaratively. The other
  themes' CSS/jsonc were not ported.
- **`hyprswitch` removed.** Upstream renamed it to **`hyprshell`** with a
  different CLI, so the old Alt-Tab binds/`exec-once` would break. They're
  dropped; re-add via the `hyprshell` flake + new CLI if you want the switcher.
- **`hyprwat` (SUPER+F12 / waybar audio click) is dead.** It's AUR-only and not
  in nixpkgs. `pavucontrol` and `wpctl` cover audio selection until it's packaged.
- **Daemon autostart.** `hyprpaper` / `hypridle` / `waybar` run as Home Manager
  systemd user services (on `graphical-session.target`); `swaync` / `swayosd-server`
  are still launched from Hyprland `exec-once`. If something doesn't start, check
  `systemctl --user status <name>`.
- **`wlogout/layout`** actions point at `~/.config/hypr/scripts/power.sh` (a path
  inherited from the Arch dotfiles); the scripts tree deploys to `~/.config/scripts`.
  Adjust if you use the wlogout menu directly.
- **`system-update.sh`** is Arch-only and self-exits on NixOS (harmless).
- **Neovim is out of scope** (no longer used — not ported).
