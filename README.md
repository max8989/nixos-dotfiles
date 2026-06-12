# nixos-dotfiles

Fully declarative **NixOS + Home Manager** configuration for a Hyprland desktop,
themed **Catppuccin Mocha**. Migrated from an Arch/Hyprland dotfiles setup and
rewritten as pure Nix (no live-symlinked dotfile tree).

**Hosts:**
- `thinkpad-x1-carbon-g7` — ThinkPad X1 Carbon (7th Gen).
- `thinkpad-x1-carbon-g12` — ThinkPad X1 Carbon (Gen 12, 21KC; Intel Core Ultra 5
  125U / Meteor Lake, btrfs root).

Both hosts share one system module (`hosts/common.nix`) and the same Home Manager
config; each only adds its own generated `hardware-configuration.nix` (plus, for
the Gen 12, the Meteor Lake iGPU video stack).

## What's inside

| Area | Module | Approach |
|------|--------|----------|
| System (boot, audio, login, fonts, fcitx5, fingerprint, …) | `hosts/common.nix` (shared) + `hosts/<host>/configuration.nix` | NixOS options |
| Compositor + keybindings | `home/hyprland.nix` | `wayland.windowManager.hyprland.settings` (all binds inlined) |
| Status bar | `home/waybar.nix` | `programs.waybar.settings` + `readFile style.css` |
| Lock / idle / wallpaper | `home/desktop.nix` | `programs.hyprlock` · `services.hypridle` · `services.hyprpaper` |
| Launcher / menus / OSD | `home/desktop.nix` | `programs.wofi` + rofi/wlogout/swayosd files |
| Terminal | `home/kitty.nix` | `programs.kitty` (+ `themeFile = "Catppuccin-Mocha"`) |
| Shell / prompt | `home/shell.nix` | bash + `programs.starship` |
| Scripts + timers | `home/scripts.nix` | in-repo scripts + systemd user timers |
| Cursor / GTK / icons / Qt | `home/theming.nix` | `home.pointerCursor` · `gtk` · `qt` |

Structured configs are converted to native Nix attribute sets. Opaque blobs that
have no attribute-set form — CSS, rofi `.rasi`, kanata `.kbd`, the starship TOML,
shell scripts, images — live under `home/files/` and are referenced from
Nix (`readFile` / `.source` / `importTOML`). That keeps the repo self-contained
and the deployment fully declarative.

```
flake.nix                      # inputs + per-user vars + `hosts` list → one config each
hosts/
  common.nix                   # shared system config (imported by every host)
  thinkpad-x1-carbon-g7/
    configuration.nix          # imports ../common.nix + hardware
    hardware-configuration.nix # PLACEHOLDER — regenerate on the machine
  thinkpad-x1-carbon-g12/
    configuration.nix          # ../common.nix + Meteor Lake iGPU video stack
    hardware-configuration.nix # PLACEHOLDER — regenerate on the machine
home/
  home.nix  hyprland.nix  waybar.nix  kitty.nix  shell.nix
  desktop.nix  scripts.nix  theming.nix
  starship.toml
  files/                       # CSS, rasi, scripts, icons, backgrounds, …
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
name to the list, and regenerate its `hardware-configuration.nix` on the box.
`home.homeDirectory`, the NixOS user (`users.users.${username}`), and the flake's
host path all derive from the variables; runtime config paths use `~`, so they
need no edits.

## Install

A from-scratch walkthrough — from NixOS install media to this flake running on the
machine. Commands assume the **Gen 12** (`thinkpad-x1-carbon-g12`: UEFI, NVMe,
btrfs root); set `HOST=thinkpad-x1-carbon-g7` for the 7th Gen. The committed
`hardware-configuration.nix` files are placeholders (**not bootable**) that exist
only so `nix flake check` evaluates — you regenerate the real one in step 5.

> ⚠️ **Step 3 erases the target disk.** Confirm the device name with `lsblk`
> before running any `parted`/`mkfs` command. Official manual:
> <https://nixos.org/manual/nixos/stable/#sec-installation>.

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

### 1b. (Optional) Continue over SSH

Handy for doing the rest from another machine (copy-paste, a real terminal). The
installer logs in as the `nixos` user, which has no password and so can't SSH in
yet — set one, then find the laptop's IP:

```sh
passwd                # set a password for the 'nixos' user (sshd is already running)
ip -c a               # note the wlan IP, e.g. 192.168.2.31
```

From your other machine, connect as `nixos` and continue with the steps below:

```sh
ssh nixos@<IP>        # e.g. ssh nixos@192.168.2.31
```

### 2. Enable flakes for this installer session

`nixos-install --flake` needs the flakes feature turned on:

```sh
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 3. Partition + format (UEFI / GPT, btrfs root)

Identify the disk with `lsblk` — the X1's NVMe is usually `/dev/nvme0n1`, whose
partitions are suffixed `p1`, `p2`, …. Set `DISK` to match, then:

```sh
DISK=/dev/nvme0n1

parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MB 1GB      # EFI system partition
parted $DISK -- set 1 esp on
parted $DISK -- mkpart nixos 1GB 100%         # root fills the rest

mkfs.fat -F 32 -n boot ${DISK}p1
mkfs.btrfs -L nixos ${DISK}p2
```

Create a btrfs `@` subvolume (matches the `subvol=@` in the host's hardware
placeholder) and mount everything under `/mnt`:

```sh
mount ${DISK}p2 /mnt
btrfs subvolume create /mnt/@
umount /mnt

mount -o subvol=@,compress=zstd,noatime ${DISK}p2 /mnt
mkdir -p /mnt/boot
mount -o umask=077 ${DISK}p1 /mnt/boot
```

> Optional swap: add a `@swap` subvolume + swapfile (or a swap partition) and
> `swapon` it — `nixos-generate-config` records whatever it finds.

### 4. Clone this repo + generate real hardware config

```sh
HOST=thinkpad-x1-carbon-g12        # or: thinkpad-x1-carbon-g7
nix-shell -p git
git clone https://github.com/max8989/nixos-dotfiles /mnt/etc/nixos/nixos-dotfiles
cd /mnt/etc/nixos/nixos-dotfiles
nixos-generate-config --root /mnt --show-hardware-config \
  > hosts/$HOST/hardware-configuration.nix
git add hosts/$HOST/hardware-configuration.nix   # flakes only see git-tracked files
```

### 5. Review before building (a few values are intentionally TODO)

- `system.stateVersion` (`hosts/common.nix`) **and** `home.stateVersion`
  (`home/home.nix`) → preset to `26.05` (the current ISO). Only change these if you
  install a different release, and never bump them after install.
- `time.timeZone` (currently `America/Toronto`) and `i18n.defaultLocale`.
- Confirm the generated `hardware-configuration.nix` shows your real filesystems.

### 6. Install + set passwords

```sh
nixos-install --flake .#$HOST                  # prompts for the root password at the end
nixos-enter --root /mnt -c 'passwd <username>' # set your login user's password
reboot
```

### 7. First boot

Remove the USB and boot. Log in at **tuigreet → Hyprland** as your user, then
enroll the fingerprint reader with `fprintd-enroll`. From here on, apply changes
with the rebuild command below.

### Rebuild after changes

```sh
sudo nixos-rebuild switch --flake ~/path/to/nixos-dotfiles#thinkpad-x1-carbon-g12
```

### (Optional) test in a VM first

```sh
nix build .#nixosConfigurations.thinkpad-x1-carbon-g12.config.system.build.vm
./result/bin/run-thinkpad-x1-carbon-g12-vm
```

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
