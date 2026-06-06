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
hosts/<hostname>/configuration.nix         # imports ../common.nix + hardware + host-specific overrides
hosts/<hostname>/hardware-configuration.nix # PLACEHOLDER — regenerate on the machine, never hand-edit to "fix"
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
`hosts/common.nix`. Genuinely per-machine bits (filesystems, kernel modules,
microcode, GPU driver packages) go in the host's `hardware-configuration.nix`
(regenerated) or its `configuration.nix` (for things that must survive a
`nixos-generate-config` regen, e.g. the Gen 12's `hardware.graphics.extraPackages`
= `intel-media-driver` + `vpl-gpu-rt` and `LIBVA_DRIVER_NAME = "iHD"`).

**Two-tier rule for configs:**
1. **Structured config → native Nix attribute sets.** Hyprland binds, Waybar
   modules, hyprlock/hypridle/hyprpaper, wofi, kitty, starship all live as
   `settings = { … }` / list-of-attrs in the `.nix` files. New config of this
   kind goes here, not into a raw file.
2. **Opaque blobs → `home/files/`,** referenced from Nix via
   `builtins.readFile` / `.source` / `lib.importTOML`. CSS, rofi `.rasi`,
   kanata `.kbd`, shell scripts, and images have no meaningful attribute-set
   form — keep them as real files (still pure: they're inside the flake).

**Do not** reintroduce live-symlinked dotfiles or reach outside the repo root —
flakes only see git-tracked files inside the flake root.

## Gotchas specific to this repo

- **Single theme.** Mocha is baked in. There is no runtime theme switcher (it
  was dropped because the Nix store is immutable). To change theme you edit Nix
  and rebuild.
- **Daemon autostart is split:** `hyprpaper` / `hypridle` / `waybar` run as HM
  systemd user services (`graphical-session.target`); `swaync` /
  `swayosd-server` / `kanata` / cliphist / the polkit agent are launched from
  Hyprland `exec-once` in `home/hyprland.nix`. Don't launch the
  systemd-managed ones from `exec-once` too (double instances).
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
