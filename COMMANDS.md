# Commands

Day-to-day cheat sheet for running this config. Setup/install lives in
[README.md](README.md); editing rules live in [CLAUDE.md](CLAUDE.md).

Everything below assumes you're in the repo:

```sh
cd ~/repos/nixos-dotfiles
```

Host names (the `#…` in every flake command):

| Machine | Flake attr |
|---------|------------|
| ThinkPad X1 Carbon Gen 12 (21KC) | `thinkpad-x1-carbon-g12` |
| ThinkPad X1 Carbon 7th Gen | `thinkpad-x1-carbon-g7` |

## The one you'll use every time

```sh
# evaluate BOTH hosts — catches typos/renamed attrs
nix flake check
# build + activate now
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
```

⚠️ **`git add` new files before rebuilding.** A flake only sees git-tracked
files inside the repo root — a new file in `home/files/` that isn't staged
simply doesn't exist to the build (`error: path … does not exist`).

Variants of `switch`:

```sh
sudo nixos-rebuild boot   --flake .#thinkpad-x1-carbon-g12   # apply on next reboot only
sudo nixos-rebuild test   --flake .#thinkpad-x1-carbon-g12   # activate now, don't touch the boot menu
sudo nixos-rebuild build  --flake .#thinkpad-x1-carbon-g12   # just build, ./result symlink, activate nothing
sudo nixos-rebuild dry-activate --flake .#thinkpad-x1-carbon-g12  # show what would change
```

Use `test` when you're unsure a change is safe: if it wedges the session, a
reboot lands you back on the previous generation.

## Updating

```sh
nix flake update                    # bump every input, rewrites flake.lock
nix flake update nixpkgs            # bump one input only
nix flake metadata                  # show current input revisions + lock age
```

Then always:

```sh
nix flake check
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
git add flake.lock && git commit -m "update lock"
```

After an input bump, re-check the "Verify on first build" list in the README —
that's the set of attribute names most likely to have been renamed upstream.

## When a rebuild breaks the system

```sh
sudo nixos-rebuild switch --rollback        # back to the previous generation
nixos-rebuild list-generations              # what's available (add --json for scripting)
```

Or pick an older generation from the systemd-boot menu at boot. Generations
are never deleted by a rebuild, only by garbage collection.

## Disk space / garbage collection

Nothing in this config runs GC automatically — do it by hand when `/nix` gets
fat:

```sh
df -h /                                          # check first
sudo nix-collect-garbage --delete-older-than 14d # drop system generations older than 14 days
nix-collect-garbage --delete-older-than 14d      # same for your user profile
sudo nix store optimise                          # hardlink duplicate store paths
```

`sudo nix-collect-garbage -d` deletes **all** old generations — including the
rollback targets above. Rebuild first, confirm the new generation is good, then
run it.

Bootloader entries are pruned on the next rebuild after GC.

## Packages

Add the attribute name to the right list, then rebuild:

| What | Where |
|------|-------|
| User app / CLI tool | `home/home.nix` → `home.packages` |
| System service or daemon | `hosts/common.nix` (`services.<name>.enable = true;`) |
| Font | `hosts/common.nix` → `fonts.packages` |
| One machine only (GPU, kernel modules) | `hosts/<host>/configuration.nix` |

Find the attribute first:

```sh
nix search nixpkgs ripgrep           # or https://search.nixos.org/packages
```

Try something once without installing it:

```sh
nix shell nixpkgs#ripgrep            # temporary shell with it on PATH
nix run nixpkgs#ripgrep -- --version # run it and exit
```

Don't `pip install` / `npm -g` / drop binaries in `~/.local/bin` and expect
them to survive — the declarative list is the source of truth.

## Desktop services

`hyprpaper` / `hypridle` / `waybar` / `kanata` are Home Manager **systemd user
services**, so use `--user` (no sudo):

```sh
systemctl --user status  waybar
systemctl --user restart waybar          # also: hyprpaper, hypridle, kanata
journalctl --user -u waybar -e           # logs, jump to end
journalctl --user -u waybar -f           # follow

systemctl --user list-timers             # battery-level, reminders-notify
```

If **several** desktop daemons are missing at once, check the target before
blaming any one of them — a Hyprland config parse error takes the whole session
target down:

```sh
systemctl --user is-active graphical-session.target
```

`swaync` / `swayosd-server` / cliphist / the polkit agent are *not* systemd
units — they start from the `hyprland.start` hook in
`home/files/hypr/hyprland.lua`, so they're also lost when that file fails to
parse.

## Before rebuilding after a Hyprland edit

```sh
luac -p home/files/hypr/*.lua        # syntax check — a parse error = bind-less session
```

## Formatting

`nixfmt` isn't installed on the system; run it from nixpkgs:

```sh
nix run nixpkgs#nixfmt -- **/*.nix   # RFC-style, 2-space (zsh glob; use **/*.nix)
```

This flake has no `formatter` output, so plain `nix fmt` won't work.

## Test in a VM (no risk to the running system)

```sh
nix build .#nixosConfigurations.thinkpad-x1-carbon-g12.config.system.build.vm
./result/bin/run-thinkpad-x1-carbon-g12-vm
```

Don't commit `result*` symlinks (they're gitignored).

## Poking at the config

```sh
nixos-rebuild repl --flake .#thinkpad-x1-carbon-g12   # nix repl with config/pkgs in scope
nix eval .#nixosConfigurations.thinkpad-x1-carbon-g12.config.networking.hostName
nix flake show                                        # what this flake exposes
```

Inside the repl, `config.services.…` / `config.home-manager.users.maxime.…`
resolve the final values, which is the fastest way to answer "did that option
actually take effect".

## Machine bits

```sh
passwd                    # change your password (first boot password is `changeme`)
fprintd-enroll            # enroll a fingerprint
nmtui                     # Wi-Fi from a console
```

## Not applicable here

- **No standalone `home-manager switch`.** Home Manager is imported as a NixOS
  module, so `nixos-rebuild switch` applies home config too.
- **No `nix-env -i` / `nix profile install`** for anything you want to keep —
  it works, but the next rebuild won't know about it. Edit `home/home.nix`.
- **Never bump `system.stateVersion` / `home.stateVersion`** (both `26.05`) to
  "get newer behavior" — they record the release you installed from.
