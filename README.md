# nixos-dotfiles

Fully declarative **NixOS + Home Manager** configuration for a Hyprland desktop,
with a self-authored **Quickshell desktop styled from Omarchy**, with eight
runtime themes including three light palettes.
Migrated from an Arch/Hyprland dotfiles setup and
rewritten as pure Nix (no live-symlinked dotfile tree).

**Hosts:**
- `thinkpad-x1-carbon-g12` — ThinkPad X1 Carbon (Gen 12, 21KC; Intel Core Ultra 5
  125U / Meteor Lake, btrfs root). Desktop.
- `homeserver` — Gigabyte H81M-HD2 (i5-4460 Haswell, 16 GB, RTX 3070). Headless
  media server: the Docker Compose stack (Traefik, Jellyfin, *arr, qBittorrent
  behind a PIA WireGuard container, SABnzbd, Homepage, …) runs unchanged on top
  of NixOS-provided Docker + NVIDIA container toolkit. Installed on the Corsair
  Neutron XT SSD with BIOS GRUB, an ext4 root, and an 8.8 GiB swap partition.
  The separate Samsung SSD is not managed by this profile.

Every host imports `hosts/common.nix` (role-agnostic system config); graphical
hosts additionally import `hosts/desktop.nix` (Hyprland, greetd, PipeWire,
fonts, laptop peripherals). The `desktop` flag per host in `flake.nix` also
selects the Home Manager profile: `home/home.nix` (full desktop) or
`home/server.nix` (CLI tools and server administration). Both import
`home/cli.nix` for shared command-line essentials. Each host dir adds its declarative
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
| Dictation | `home/dictation.nix` + Kanata + Hyprland | Hold Caps + V; local Voxtype/Whisper transcription into the focused input |
| Shell (bar, launcher, menus, notifications, OSD, authentication, lock) | `home/quickshell.nix` + `home/files/quickshell/` | Generated JSON + modular QML; systemd user service |
| Idle / wallpaper / night light | `home/desktop.nix` | `services.hypridle` · `services.hyprpaper` · `services.hyprsunset` |
| Terminal | `home/kitty.nix` | Automatic dark/light colors, JetBrainsMono Nerd Font 9pt, opacity 0.94 |
| Firefox | `home/firefox.nix` + `home/files/firefox/userChrome.css` | Compact density, top toolbar and vertical tabs revealed from the top/left edge |
| Shell / prompt | `home/shell.nix` | zsh (+fzf, zoxide, eza/bat aliases) + `programs.starship` |
| CLI packages | `home/cli.nix` + `home/server.nix` | Shared utilities, Git/Docker tools and core runtimes; extra headless administration tools |
| Independent scripts | `home/scripts.nix` + `home/capture-tools.nix` | Frozen-screen capture, Swappy editing, recording and RSS tools |
| Theme / TUIs | `home/theme.nix` + `home/omarchy.nix` | Runtime theme switcher, btop and VS Code; Superfile/fzf/prompt share the selected palette |
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
    configuration.nix          # ../common.nix + BIOS GRUB + key-only SSH + headless NVIDIA
    disko.nix                  # installed Corsair SSD: MBR + ext4 root + swap
    hardware-configuration.nix # generated on the installed server with --no-filesystems
    portainer.nix              # Portainer CE Docker service, persistent data, HTTPS 9443
home/
  home.nix                     # full desktop HM profile (desktop hosts)
  cli.nix                      # CLI essentials shared by both profiles
  server.nix                   # shell + shared CLI + administration (headless hosts)
  hyprland.nix  quickshell.nix  kitty.nix  shell.nix
  desktop.nix  dictation.nix  scripts.nix  theming.nix
  starship.toml
  files/                       # CSS, rasi, hypr/*.lua, scripts, icons, backgrounds, …
```

## Speech to text

Hold **Caps Lock**, then hold **V** and speak. Release **V** to transcribe and
type into the focused text field. Omarchy's shortcuts also work: hold **F9**
or **Right Alt**, or press **Super + Ctrl + X** to start/stop recording.
Use F9 on layouts where Right Alt is AltGr. Caps keeps its existing
Escape/navigation behavior; ordinary V and Super + V (clipboard history)
keep working. Caps+V uses Kanata's F13 keycode directly because the default
keyboard map names that key `XF86Tools`.

This adapts [Omarchy's Voxtype backend](https://github.com/basecamp/omarchy/blob/quattro/bin/omarchy-dictation-voxtype)
and [press/release bindings](https://github.com/basecamp/omarchy/blob/quattro/default/hypr/bindings/dictation.lua).
The [Omarchy manual](https://github.com/basecamp/omarchy/blob/quattro/manual/11-text-extraction-dictation.md)
also offers Superwhisper; this configuration uses local Voxtype/Whisper.
The multilingual Whisper base model (148 MB) is pinned and downloaded by Nix
during the build. Language detection is limited to French and English, with a
French Canadian (Québec) vocabulary hint and no translation or cloud service.
Speak either language using the same shortcut. The Vulkan build uses the
desktop GPU for recognition. Change recognition settings in `home/dictation.nix`;
Home Manager generates `~/.config/voxtype/config.toml`.

Voxtype starts with the graphical session, records the default microphone,
pauses media while recording, and limits recordings to 60 seconds. Its
[upstream waveform HUD](https://github.com/peteonrails/voxtype/tree/v1.0.1/quickshell)
shows live microphone levels while recording, stays visible during transcription,
and disappears when finished. Recording/transcription notifications are disabled.
The matching Quickshell assets and audio bridge are wired declaratively through
the Voxtype service. If automatic typing fails, the text is copied to
the clipboard. Check the desktop's microphone mute/input settings if recordings
are silent. Caps+V applies to keyboards managed by Kanata; the existing
Keychron exclusions remain in `home/files/kanata/config.kbd`. The Omarchy
shortcuts work independently of Kanata.

Apply with the normal rebuild, then restart Kanata so it reads the new mapping:

```sh
sudo -A nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
systemctl --user restart kanata
```

For diagnostics, use `systemctl --user status voxtype` and
`journalctl --user -u voxtype -b`.

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
desktop-fingerprint setup
```

### Where the repo lives after install

Clone the repo on the new machine and rebuild from there — flakes build from
**any** path, the location is not special:

```sh
git clone git@github.com:max8989/nixos-dotfiles.git ~/repos/nixos-dotfiles
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

### Fingerprint authentication

The desktop copies Omarchy's fingerprint workflow for **lock-screen unlock,
sudo, and graphical administrator prompts (polkit)**. The system configuration
lives in `hosts/fingerprint.nix`; the Quickshell lock uses separate password and
fingerprint PAM conversations so you can type your password while it scans.

After rebuilding, open **Desktop menu → Setup → Fingerprint → Enroll
fingerprint**, or run `desktop-fingerprint setup` in a terminal. Follow the
enrollment and verification prompts to choose and scan the requested finger.
The same menu offers **Test fingerprint** and **Enrolled fingerprints**;
the terminal equivalents are `desktop-fingerprint verify` and
`desktop-fingerprint list`.

Press **Super + N**, choose **Lock**, then touch the enrolled finger. An enrolled
reader shows a fingerprint prompt; failed scans retry automatically. Device
errors back off and show an unavailable message while password entry stays
available. A transient enrollment-query error is retried, while a confirmed
empty enrollment hides the fingerprint prompt. Each lock checks enrollment
again, so adding a finger does not require restarting the shell.

For sudo and polkit, the fingerprint check precedes the normal password
fallback. A closed laptop lid skips that check so a docked session can prompt
for a password immediately. After suspend, the system queues a restart of an
active fingerprint daemon, and the lock retries after the reader recovers.
Fingerprint enrollment is local machine state and must be completed on each
new installation.

Bitwarden is installed system-wide by `hosts/desktop.nix` so polkit loads its
unlock policy. GNOME Keyring provides the secure storage it needs, and greetd
unlocks the keyring with your Linux login password. In Bitwarden, enable
**File → Settings → Security → Unlock with system authentication**. If a keyring
setup dialog appears, use your Linux login password so it unlocks at login.

`home/zen.nix` registers Bitwarden's native messaging helper in the Zen wrapper.
After rebuilding it, fully restart Zen, keep the Bitwarden desktop app running,
and enable **Settings → Account security → Unlock with biometrics** in the
extension.

To apply a working tree that still has untracked new files, use the path flake:

```sh
sudo -A nixos-rebuild switch --flake path:.#thinkpad-x1-carbon-g12
desktop-fingerprint setup
```

Upstream references: Omarchy's [setup script](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-setup-security-fingerprint),
[lock fingerprint model](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/lock/FingerprintModel.js),
and [resume hook](https://github.com/omacom/omarchy/blob/quattro/default/systemd/system-sleep/fprintd-resume).
The adaptation uses NixOS modules rather than editing `/etc/pam.d` at runtime.

### Firefox compact layout

`home/firefox.nix` manages Firefox's compact density and vertical tabs.
`home/files/firefox/userChrome.css` hides the top toolbars and collapsed tab rail,
leaving a 4px hover target at the top and an 8px target at the left. Revealed bars
overlay the page. `Ctrl+L` reveals and focuses the address bar; menus and popups
keep the toolbar visible while in use. Toolbar customization and website
fullscreen use Firefox's normal layout.

Rebuild, then fully quit and reopen Firefox. The ThinkPad configuration adopts
the existing `iuvdm42p.default` profile, preserving its session, extensions and
bookmarks. When reinstalling, update that host's
`programs.firefox.profiles.default.path` to the existing profile's directory
before rebuilding, or remove the override for a fresh `default` profile.

The sidebar uses Firefox's [native hover expansion](https://firefox-source-docs.mozilla.org/browser/components/sidebar/docs/index.html).
The toolbar and rail hiding use [userChrome.css](https://support.mozilla.org/en-US/kb/contributors-guide-firefox-advanced-customization),
which can need adjustments after Firefox updates. To disable the custom hiding,
set `toolkit.legacyUserProfileCustomizations.stylesheets` to `false` in
`about:config` and restart Firefox. Remove `userChrome` from `home/firefox.nix`
for a persistent rollback through Home Manager.

### Installed home server

The server at `192.168.2.43` has this repository in `~/repos/nixos-dotfiles`.
Its `homeserver` profile uses the installation's existing Corsair SSD root and
swap partitions, BIOS GRUB, and authorized SSH key. The profile sets the host
name to `homeserver` and uses the headless Home Manager configuration.
`system.stateVersion` and `home.stateVersion` remain `26.05`.

The server shares tools such as lazygit, lazydocker, Docker Compose, GitHub CLI,
Yazi, eza/bat, ripgrep, jq, Node.js, Bun, and uv with the desktop. Its own profile
adds tmux, btop, ncdu, rsync, Python, hardware/disk/network diagnostics, and
nixfmt. Git and Vim are installed system-wide by `hosts/common.nix`.

To activate it on the server:

```sh
cd ~/repos/nixos-dotfiles
git pull --ff-only
nix flake check
sudo -A nixos-rebuild switch --flake .#homeserver
```

Until the first rebuild installs Git and enables flakes, use `nix-shell -p git`
and add `--extra-experimental-features 'nix-command flakes'` to Nix commands.
Activation requires sudo authentication on the server.

Hardware can be regenerated with
`nixos-generate-config --no-filesystems --show-hardware-config`; filesystems
and swap stay in `hosts/homeserver/disko.nix`. Applying this profile uses the
existing partitions. Running the fresh-install disko commands repartitions
and formats the Corsair SSD.

### Jellyfin and media services

The restored Compose project and all its application configs live at
`~/repos/docker-compose-nas` on the Corsair system disk. The Samsung 860 EVO
1 TB SSD has one ext4 partition, labeled `media-library`, mounted by UUID at
`/mnt/data`. The movies, TV, music, torrent, and Usenet directories were copied
from Arch with their existing paths. Containers continue to see `/data`, so
Jellyfin's users, library definitions, metadata, and watch history keep the
same paths. The Samsung 870 EVO 500 GB SSD retains the original Arch setup.

The services run with `docker compose up -d` and their original restart
policies. `hosts/homeserver/media-storage.nix` only declares the existing media
filesystem and makes Docker wait for it at boot. The restored Compose file
uses the NVIDIA CDI device and publishes Jellyfin's HTTP port. Jellyfin uses
the image version recorded in the Arch container; update that version in the
Compose file when upgrading. The existing reverse proxy and `/jellyfin` base
path are preserved. Direct LAN access is
`http://192.168.2.43:8096/jellyfin/`.

The runtime `.env` uses the NixOS user's group ID (`100`). It contains
credentials and stays on the server with mode `0600`.
An untouched copy of the original project is protected at
`/var/backups/media-stack-arch-2026-10-11`.

```sh
cd ~/repos/docker-compose-nas
docker compose up -d
docker compose ps
docker compose logs --tail 50 jellyfin
```

### Portainer

After activating the server profile, open `https://192.168.2.43:9443`. The
default HTTPS certificate is self-signed. For the initial administrator setup,
retrieve the setup token in your own SSH terminal on the server:

```sh
docker logs portainer 2>&1 | rg '^setup_token=' | tail -n 1
```

Paste the value after `setup_token=` into the setup screen and create the
administrator account within five minutes of Portainer starting. If setup has
timed out, run `docker restart portainer`, retrieve the latest token, and reload
the page. See the [setup token FAQ](https://docs.portainer.io/faqs/installing/setup-token).

Portainer CE connects to the host's Docker socket and stores its configuration
in the persistent Docker volume `portainer_data`.

`hosts/homeserver/portainer.nix` pins the LTS image version and digest. Update
that declaration and rebuild to upgrade it. NixOS manages the container through
`docker-portainer.service`:

```sh
systemctl status docker-portainer
sudo -A systemctl restart docker-portainer
```

See the [official Docker installation guide](https://docs.portainer.io/start/install-ce/server/docker/linux)
for Portainer's initial setup. The separate Compose media stack can be managed
through Portainer after it is restored to the server.

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
| A CLI tool shared by desktop and server (`ripgrep`, lazygit, …) | `home/cli.nix` → `home.packages` | add the attr to the list |
| A server-only CLI tool or diagnostic | `home/server.nix` → `home.packages` | add the attr to the list |
| A desktop app (browsers, GUI editors, …) | `home/home.nix` → `home.packages` | add the attr to the list |
| A system service / daemon (docker, flatpak, firewall, printing, …) | `hosts/common.nix` | use its NixOS option, e.g. `services.<name>.enable = true;` |
| A font | `hosts/common.nix` → `fonts.packages` | add the attr to the list |
| Something only one machine needs (GPU drivers, kernel modules) | `hosts/<host>/configuration.nix` | per-host option |

For example, shared CLI packages belong in `home/cli.nix`:

```nix
# home/cli.nix — inside home.packages = with pkgs; [ … ];
home.packages = with pkgs; [
  # …existing…
  htop
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

- **Runtime Omarchy-style themes.** Tokyo Night preserves the effective theme
  from the Omarchy 4.0.0.alpha snapshot captured 2026-10-10. Catppuccin Latte
  is joined by Flexoki Light and White as light options, each with its Omarchy
  wallpaper. Nix builds all eight themes;
  `desktop-theme set <name>` changes the selected theme immediately and stores
  the choice across rebuilds. **Style → Wallpaper** (Super+Ctrl+Space) selects a
  custom image and remembers it separately for each theme; **Restore theme
  default** returns that theme to its bundled image. Selected images survive
  rebuilds and moving the original file. See [wallpaper commands](COMMANDS.md#change-wallpaper)
  for terminal usage. The headless profile retains its Jade CLI palette.
  GTK uses Adwaita/Yaru icons, and Qt uses Kvantum with matching palettes. Snapshot
  assets and license notices live in `home/files/omarchy/`.
- **Retained desktop features.** The transparent 26px top bar keeps reminders,
  status indicators, tray controls and existing responsive visibility rules.
  The shell source and wallpaper images were absent from the Tokyo Night
  snapshot, so Quickshell uses its captured tokens and the bundled NixOS aurora
  wallpaper for that theme. Kitty is the only migrated terminal; Swappy handles
  editing.
- **Alt-Tab uses Quickshell's recent-window picker.** Hold ALT and tap TAB to
  cycle through windows across workspaces and monitors; ALT+SHIFT+TAB goes
  backwards. Arrow keys also navigate; release ALT or press Enter to focus
  the selection, or Escape to cancel. The Lua bindings call the `switcher`
  IPC target. `panels/WindowSwitcher.qml` snapshots Hyprland's focus history
  without requiring numeric workspace IDs, including for special workspaces.
  Hyprshell and its local compatibility patch have been removed.
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

**Super+M** opens the global Desktop menu. Its first page fits without scrolling:
**Apps, Learn, Trigger, Style, Setup, About, System**. Setup groups device,
connection, notification and configuration settings. System groups presentation
mode, power profiles, battery and session actions. Learn contains editor references;
Trigger groups capture, clipboard, files, workspaces, calendar, reminders and media.
The first category stays selected when the menu opens beneath a stationary cursor;
moving the pointer deliberately selects the row beneath it.

Type to search across actions (for example
`volume`, `dnd`, `wifi` or `restart`), use Up/Down to select, and Enter to open
or toggle. Right opens the selected submenu; actions such as mute, theme
selection and restart require Enter. Left returns to the previous menu,
restoring its search and selection, and does nothing at the root. Backspace
also goes back when the search is empty. A breadcrumb shows the current path.
Ctrl+Minus/Ctrl+Plus adjusts volume, microphone level, brightness and night
light temperature; Ctrl+Equal also increases the value. Ordinary minus/plus
characters still type into search. Escape or Alt+Left returns to the previous
menu; Escape at the root closes it. Ctrl+L focuses and selects the search text.
Sliders, the calendar and password fields retain their own arrow controls.
Configuration files open in **Neovim inside Kitty**, and `EDITOR` / `VISUAL`
default to `nvim`.

Open **Style → Theme** there to choose Tokyo Night, Catppuccin Latte, Flexoki
Light, White, Osaka Jade, Catppuccin Mocha, Gruvbox or Nord, or press
**Super+Ctrl+Shift+Space** to open the theme menu directly.
Searching `theme` at the root shows only **Theme**; palette names and light/dark
choices are searchable inside that picker.
From a terminal, use `desktop-theme list`, `desktop-theme current`, or
`desktop-theme set flexoki-light` (or `white`, `osaka-jade`, `catppuccin`, `gruvbox`, `nord`,
`catppuccin-latte`, `tokyo-night`). The selection persists in XDG state across
logins and rebuilds. The additional themes use Omarchy's original
palettes, default wallpapers, icon themes, Kitty/btop templates and VS Code
theme choices. White uses Omarchy's generated VS Code template; Flexoki Light
and White also have recolored light Kvantum assets. See
`home/files/omarchy/PROVENANCE.md` for pinned sources.
It changes Quickshell, Hyprland, wallpaper, Kitty, GTK/Qt/KDE, Fcitx, btop,
VS Code, Superfile, fzf and Starship. Apps that only read their theme at launch
may need reopening; Neovim keeps its separately managed theme.
The Powerline terminal prompt follows the selected palette on its next prompt,
including terminals already open when switching themes.
Running Kitty windows update their colors immediately during a theme switch.

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
