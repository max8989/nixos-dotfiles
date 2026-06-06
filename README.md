# nixos-dotfiles

Fully declarative **NixOS + Home Manager** configuration for a Hyprland desktop,
themed **Catppuccin Mocha**. Migrated from an Arch/Hyprland dotfiles setup and
rewritten as pure Nix (no live-symlinked dotfile tree).

**Host:** `x1carbon` — ThinkPad X1 Carbon (7th Gen).

## What's inside

| Area | Module | Approach |
|------|--------|----------|
| System (boot, audio, login, fonts, fcitx5, fingerprint, …) | `hosts/x1carbon/configuration.nix` | NixOS options |
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
flake.nix                      # inputs + per-user vars (username/fullName/hostname)
hosts/<hostname>/
  configuration.nix
  hardware-configuration.nix   # PLACEHOLDER — regenerate on the machine
home/
  home.nix  hyprland.nix  waybar.nix  kitty.nix  shell.nix
  desktop.nix  scripts.nix  theming.nix
  starship.toml
  files/                       # CSS, rasi, scripts, icons, backgrounds, …
```

## Make it your own

The config is parameterized — to adopt it you don't need to find-and-replace a
username. Edit the three values at the top of the `let` block in `flake.nix`:

```nix
username = "maxime";       # your login name → home dir becomes /home/<username>
fullName = "Maxime Gagne"; # account description
hostname = "x1carbon";     # must match the hosts/<hostname>/ directory
```

Then rename the host directory to match (`git mv hosts/x1carbon hosts/<your-hostname>`)
and follow the install steps below. `home.homeDirectory`, the NixOS user
(`users.users.${username}`), `networking.hostName`, and the flake's host path all
derive from those variables; runtime config paths use `~`, so they need no edits.

## Install (ThinkPad X1 Carbon 7th Gen)

1. **Boot the NixOS ISO**, partition/format, and mount the target on `/mnt`
   (and the ESP on `/mnt/boot`).

2. **Clone this repo** and generate real hardware config:
   ```sh
   nix-shell -p git
   git clone https://github.com/max8989/nixos-dotfiles /mnt/etc/nixos/nixos-dotfiles
   cd /mnt/etc/nixos/nixos-dotfiles
   nixos-generate-config --root /mnt --show-hardware-config \
     > hosts/x1carbon/hardware-configuration.nix
   ```
   > Flakes only see git-tracked files — `git add hosts/x1carbon/hardware-configuration.nix`
   > after generating it.

3. **Review before building** (a few values are intentionally TODO):
   - `system.stateVersion` / `home.stateVersion` → set to the installer's release.
   - `time.timeZone` (currently `America/Toronto`).
   - Disk labels in `hardware-configuration.nix` (replaced by the generated file).

4. **Install:**
   ```sh
   nixos-install --flake .#x1carbon
   reboot
   ```

5. **First login:** set a password (`passwd <username>`), then after reboot log in via
   tuigreet → Hyprland. Enroll the fingerprint with `fprintd-enroll`.

### Rebuild after changes

```sh
sudo nixos-rebuild switch --flake ~/path/to/nixos-dotfiles#x1carbon
```

### (Optional) test in a VM first

```sh
nix build .#nixosConfigurations.x1carbon.config.system.build.vm
./result/bin/run-x1carbon-vm
```

## Verify on first build

This config was authored without a Nix evaluator on hand, so confirm these
attribute/option names against your pinned `nixpkgs`/`home-manager` and fix any
that have moved (run `nix flake check` first):

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
