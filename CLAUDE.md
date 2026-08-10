# CLAUDE.md

Guidance for working in this repo. Read this before editing.

## What this is

A standalone, **fully declarative** NixOS + Home Manager config for a Hyprland
desktop (Catppuccin **Mocha**). Two hosts, both ThinkPad X1 Carbons:
`thinkpad-x1-carbon-g7` (7th Gen) and `thinkpad-x1-carbon-g12` (Gen 12, 21KC —
Intel Core Ultra 5 125U / Meteor Lake, btrfs root). They share one system module
(`hosts/common.nix`) and the same Home Manager config; each host dir only adds its
generated `hardware-configuration.nix` (plus the Gen 12's Meteor Lake iGPU video
stack). Migrated from an Arch/Hyprland dotfiles repo and rewritten as pure Nix.
See `README.md` for install steps and the full module map.

## Hard rule — verify library/option specifics before stating them

Before asserting any **Nix / nixpkgs / Home Manager / Hyprland / Waybar** specifics
(package attribute names, option paths, module schemas, defaults, renames), look
them up — don't rely on memory:
- Home Manager options → Context7 (`/nix-community/home-manager`) or
  <https://home-manager-options.extranix.com>.
- nixpkgs packages → `nix search nixpkgs <name>` or <https://search.nixos.org>.
- Flake inputs (zen-browser, hyprland, …) → the input's own `flake.nix` outputs.

This config was first authored **without a Nix evaluator**, so attribute names may
have drifted. Always `nix flake check` after changes (see below). The README's
"Verify on first build" list is the known-suspect set.

## Layout & conventions

```
flake.nix                         # inputs + per-user vars + `hosts` list → nixosConfigurations (genAttrs)
hosts/common.nix                  # shared NixOS system options (imported by every host)
hosts/<hostname>/configuration.nix         # imports ../common.nix + disko.nix + hardware + host-specific overrides
hosts/<hostname>/disko.nix                 # declarative disk layout (disko) — partitioning AND fileSystems.* come from here
hosts/<hostname>/hardware-configuration.nix # detected hardware ONLY (no filesystems) — regenerated at install with --no-filesystems, never hand-edit to "fix"
home/*.nix                        # Home Manager modules (imported by home.nix)
home/starship.toml                # imported via lib.importTOML
home/files/                       # opaque blobs (CSS, rasi, scripts, icons, backgrounds, kanata)
```

**Identity is parameterized.** `username` and `fullName` are defined once in the
`let` block of `flake.nix`; hosts are a `hosts` list there, and `mkHost` builds one
`nixosConfigurations.<name>` per entry via `lib.genAttrs`, threading `hostname`
(the list entry) down via `specialArgs` / `extraSpecialArgs`. Nothing else
hard-codes the user, `/home/<user>`, or the machine name — `home.homeDirectory` is
`"/home/${username}"`, the NixOS account is `users.users.${username}`,
`networking.hostName = hostname` (in `common.nix`), and the flake reads
`./hosts/${hostname}/`. To add a machine: add its name to `hosts`, create a
matching `hosts/<name>/` dir (copy an existing one), and regenerate its
`hardware-configuration.nix` on the box. To re-home entirely: change `username` /
`fullName` and rename the host entries + dirs. Do not reintroduce a literal
`maxime` / `/home/maxime` / host name anywhere else — derive from the args
(`username` is passed to `home/home.nix`, `common.nix`, and each
`configuration.nix`; runtime paths use `~` or `config.home.homeDirectory`).

**Shared vs. host-specific system config.** Anything host-agnostic goes in
`hosts/common.nix`. Genuinely per-machine bits go per host: **disk layout and
filesystems in `disko.nix`** (the disko module derives `fileSystems.*` from it —
never define `fileSystems` in `hardware-configuration.nix`, that's a conflicting
definition), kernel modules/microcode in `hardware-configuration.nix`
(regenerated with `--no-filesystems`), and everything that must survive a
`nixos-generate-config` regen in `configuration.nix` (e.g. the Gen 12's
`hardware.graphics.extraPackages` = `intel-media-driver` + `vpl-gpu-rt` and
`LIBVA_DRIVER_NAME = "iHD"`). Installs go through disko + nixos-anywhere — see
README "Install".

**This closure is too big to build in a live ISO's RAM store.** Both
`nixos-anywhere` (run from a second NixOS USB) and `disko-install` stage the
build in the installer's tmpfs `/nix/.rw-store` (~half RAM) *before* writing to
the target disk, and die with `No space left on device`. Use `--build-on-remote`,
or the two-step `disko --mode destroy,format,mount` + `nixos-install --root /mnt`
(the latter passes `--store /mnt`, so it downloads onto the disk). The Gen 12 was
installed with the two-step route; README "Install from the target itself" has
it, plus the signature scrub needed when reinstalling over LVM.

**Two-tier rule for configs:**
1. **Structured config → native Nix attribute sets.** Waybar modules,
   hyprlock/hypridle/hyprpaper, wofi, kitty, starship all live as
   `settings = { … }` / list-of-attrs in the `.nix` files. New config of this
   kind goes here, not into a raw file. **Hyprland is the exception** — see
   below.
2. **Opaque blobs → `home/files/`,** referenced from Nix via
   `builtins.readFile` / `.source` / `lib.importTOML`. CSS, rofi `.rasi`,
   kanata `.kbd`, shell scripts, and images have no meaningful attribute-set
   form — keep them as real files (still pure: they're inside the flake).

**Do not** reintroduce live-symlinked dotfiles or reach outside the repo root —
flakes only see git-tracked files inside the flake root.

## Gotchas specific to this repo

- **Hyprland config is Lua, in `home/files/hypr/`, not `settings`.**
  `configType = "lua"` (Home Manager's default from `stateVersion` 26.05) writes
  `~/.config/hypr/hyprland.lua`. `hyprland.lua` is appended via `extraConfig`;
  `keybindings.lua` goes in via `extraLuaFiles`, which is what emits the
  `package.path` setup and the `require("keybindings")` call — so `hyprland.lua`
  must **not** require it itself. `settings` is deliberately empty: under the Lua
  backend every attribute becomes an `hl.<name>(...)` call and would duplicate
  the Lua. Edit the `.lua` files, not `settings`. Syntax-check with
  `luac -p home/files/hypr/*.lua` before rebuilding — a parse error drops
  Hyprland into a bind-less emergency session.
  - Under the Lua backend, hyprlang `$variables` are invalid — `"$mainMod" =
    "SUPER"` renders as `hl.$mainMod("SUPER")` and Lua rejects it. Use Lua
    `local`s (as `keybindings.lua` does) or `settings.<name>._var`.
  - Paths outside the Nix store don't exist. The polkit agent is substituted
    into the Lua via a `@polkitAgent@` placeholder in `home/hyprland.nix`; add
    more the same way rather than hard-coding `/usr/...`.
- **Script shebangs must be `#!/usr/bin/env bash`.** NixOS has no `/bin/bash`
  and no `/bin/env` — `/bin` contains only `sh`, `/usr/bin` only `env`. A script
  in `home/files/**` with an Arch-style `#!/bin/bash` deploys fine and then dies
  at runtime with `bad interpreter`, which surfaces as a keybind or waybar
  module that silently does nothing. Check with
  `grep -rn '^#!' home/files --include='*.sh' | grep -v '#!/usr/bin/env'`
  after copying anything in from the Arch dotfiles.
- **Scripts must create their own output dirs.** `$HOME` is not pre-populated on
  a fresh install (no `~/Pictures/Screenshots`, etc.), and the tools these
  scripts wrap generally do not `mkdir -p` for you.
- **Single theme.** Mocha is baked in. There is no runtime theme switcher (it
  was dropped because the Nix store is immutable). To change theme you edit Nix
  and rebuild.
- **Daemon autostart is split three ways:** `hyprpaper` / `hypridle` / `waybar`
  are HM systemd user services on `graphical-session.target`; **`kanata` is a HM
  systemd user service on `default.target`** (evdev-level, so it must not depend
  on the compositor); `swaync` / `swayosd-server` / cliphist / the polkit agent
  are started from the `hyprland.start` hook in `home/files/hypr/hyprland.lua`.
  Don't also start the systemd-managed ones from the hook (double instances).
  - Anything started from that hook is lost if the Hyprland config fails to
    parse — the hook never registers. Same for `graphical-session.target`, so a
    config error takes waybar/hyprpaper/hypridle down with it. If a daemon is
    missing, check `systemctl --user is-active graphical-session.target` before
    suspecting the daemon.
- **`hyprwat` (SUPER+F12, waybar audio click) is dead** — not in nixpkgs. Left
  as-is intentionally; `pavucontrol`/`wpctl` cover it.
- **`hyprswitch` was renamed upstream to `hyprshell`** with a different CLI; the
  old binds were removed rather than ported.
- **Nix string interpolation:** in `''…''` and `"…"` strings only `${` triggers
  interpolation. Hyprlock/Waybar command strings contain `$(…)`, `$3`, `%`, `{…}`
  — all literal. If you ever need a literal `${`, escape it as `''${`.
- **Hyphenated keys are valid unquoted Nix attrs** (`on-click`, `format-wifi`);
  only keys with `/`, digits-first, or empty string need quotes (`"custom/cpu"`,
  `"1"`, `""`).

## Build / test / commit

```sh
nix flake check                                   # always run after edits (checks both hosts)
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12   # apply on the machine (or -g7)
nix build .#nixosConfigurations.thinkpad-x1-carbon-g12.config.system.build.vm  # optional VM test
nixfmt **/*.nix                                   # formatting (RFC-style, 2-space; flake has no `formatter` output)
```

- Keep `system.stateVersion` / `home.stateVersion` in sync and **never bump them
  after install** to "get newer behavior".
- Match the existing formatting (2-space indent, trailing semicolons, one attr
  per line in long sets).
- Commit only git-tracked, evaluated changes; don't commit `result*` symlinks.
