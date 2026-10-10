# Commands

Run from the repo root (`cd ~/repos/nixos-dotfiles`).
`git add` new files before rebuilding — a flake only sees git-tracked files.

## Check and rebuild

### Evaluate both hosts

Catches typos and renamed attributes.

```
nix flake check
```

### Build and activate now

```
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
```

### Activate temporarily

Does not touch the boot menu; a reboot undoes it.

```
sudo nixos-rebuild test --flake .#thinkpad-x1-carbon-g12
```

### Roll back

Go back to the previous generation.

```
sudo nixos-rebuild switch --rollback
```

### Switch desktop theme

Open **Style → Theme** with Super+M, or open the theme menu directly with
Super+Ctrl+Shift+Space. From a terminal:

```
desktop-theme list
desktop-theme current
desktop-theme set catppuccin-latte
desktop-theme set tokyo-night
```

The choice persists across rebuilds. Some applications need reopening to read
their new colors.

## Update and troubleshoot

### Update flake inputs

Afterward, check, switch, and commit `flake.lock`.

```
nix flake update
```

### Update a single flake input

Moves only that input; everything else stays pinned. Name several to update
them together.

```
nix flake update hyprland
```

There is no per-package update: almost every package comes from the one
`nixpkgs` input, so `nix flake update nixpkgs` moves all of them at once. To
advance one package alone, give it its own flake input (as `superfile` and
`zen-browser` have) and reference that in the module. An input pinned to a tag
— `superfile` is on `v1.6.0` — ignores this command; edit the tag in
`flake.nix` instead.

### Validate the desktop shell

```
nix flake check
nix build .#quickshell-vm-test --no-link
```

Restart Quickshell only while unlocked.

### Syntax-check Hyprland Lua

Run before rebuilding; a parse error can cause a session with no key bindings.

```
luac -p home/files/hypr/*.lua
```

### Find a Nix package

Use the result in `home.packages` or `common.nix`.

```
nix search nixpkgs ripgrep
```

### Try a package without installing it

```
nix shell nixpkgs#ripgrep
```

### Restart a desktop daemon

For example: Waybar, Hyprpaper, Hypridle, or Kanata.

```
systemctl --user restart quickshell
```

### View daemon logs

```
journalctl --user -u quickshell -e
```

### Check the session target

Do this first when several daemons are missing at once.

```
systemctl --user is-active graphical-session.target
```

### Format Nix files

`nixfmt` does not need to be installed system-wide.

```
nix run nixpkgs#nixfmt -- **/*.nix
```

### Free disk space

Delete Nix generations older than 14 days.

```
sudo nix-collect-garbage --delete-older-than 14d
```
