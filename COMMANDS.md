# Commands

Run from the repo root (`cd ~/repos/nixos-dotfiles`). Swap
`thinkpad-x1-carbon-g12` for `thinkpad-x1-carbon-g7` on the 7th Gen.
`git add` new files before rebuilding — a flake only sees git-tracked files.

```sh
# evaluate both hosts (catches typos / renamed attrs)
nix flake check

# build + activate now
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12

# activate now without touching the boot menu — a reboot undoes it
sudo nixos-rebuild test --flake .#thinkpad-x1-carbon-g12

# go back to the previous generation
sudo nixos-rebuild switch --rollback

# bump all flake inputs, then check + switch + commit flake.lock
nix flake update

# syntax-check Hyprland Lua before rebuilding (parse error = bind-less session)
luac -p home/files/hypr/*.lua

# find a package attribute name to add to home.packages / common.nix
nix search nixpkgs ripgrep

# try a package without installing it
nix shell nixpkgs#ripgrep

# restart a desktop daemon (waybar, hyprpaper, hypridle, kanata)
systemctl --user restart waybar

# logs for one of those daemons
journalctl --user -u waybar -e

# several daemons missing at once? check the session target first
systemctl --user is-active graphical-session.target

# format Nix files (nixfmt isn't installed system-wide)
nix run nixpkgs#nixfmt -- **/*.nix

# free disk space when /nix gets fat
sudo nix-collect-garbage --delete-older-than 14d
```
