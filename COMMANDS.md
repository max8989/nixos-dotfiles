# Commands

Run from the repo root (`cd ~/repos/nixos-dotfiles`). Swap
`thinkpad-x1-carbon-g12` for `thinkpad-x1-carbon-g7` on the 7th Gen.
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

## Update and troubleshoot

### Update flake inputs

Afterward, check, switch, and commit `flake.lock`.

```
nix flake update
```

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
systemctl --user restart waybar
```

### View daemon logs

```
journalctl --user -u waybar -e
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
