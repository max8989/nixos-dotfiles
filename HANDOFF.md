# Handoff — g7 install recovery (2026-06-12)

Session summary for the ThinkPad X1 Carbon **7th Gen** (`thinkpad-x1-carbon-g7`)
NixOS install that failed to boot, plus the repo changes made to fix it and stop
it recurring.

## TL;DR

- The g7 was installed from the **placeholder** `hardware-configuration.nix`
  (root declared `ext4`) against a real **btrfs** disk → boot dropped to
  emergency mode (`Timed out waiting for device /dev/disk/by-label/nixos`).
- Fixed live over SSH (live USB at `192.168.2.31`, user `nixos`): regenerated the
  real hardware config, moved graphics enable so regen can't wipe it, reinstalled.
- **Machine is fixed and unmounted. Action: reboot it (remove the USB).** Logs in
  as the normal user; root is intentionally locked.
- Repo updated to match + `nix flake check` passes on both hosts. **Not committed.**

## Root causes

1. **Redirect ran as the wrong user.** During install, every
   `nixos-generate-config ... > hosts/$HOST/hardware-configuration.nix` failed with
   `Permission denied` — the `>` is opened by the unprivileged `nixos` shell, not
   `sudo`, and the tree under `/mnt` is root-owned. So the generated config was
   never written; `git add` staged the committed **placeholder** and
   `nixos-install` built from it. The placeholder's `fsType = "ext4"` / no
   `subvol=@` can't mount the real btrfs root → emergency mode.

2. **Graphics enable was in a regenerated file.** `hardware.graphics.enable = true`
   lived inside the g7 `hardware-configuration.nix`. Regenerating that file (the
   fix for #1) wipes it, and nothing in `common.nix` enables graphics, so Hyprland
   would have come up with no GL/DRI. (The g12 avoids this by setting graphics in
   `configuration.nix`.)

## What was done on the machine (via SSH, live USB)

Disk layout confirmed: `/dev/nvme0n1p1` vfat `boot`, `/dev/nvme0n1p2` btrfs
`nixos` (subvol `@`). Disk/data were **not** reformatted.

1. Mounted root (`subvol=@,compress=zstd,noatime`) + ESP at `/mnt/boot`.
2. Regenerated hardware config correctly:
   `sudo nixos-generate-config --root /mnt --show-hardware-config | sudo tee hosts/thinkpad-x1-carbon-g7/hardware-configuration.nix > /dev/null`
   → now `btrfs` / `options = [ "subvol=@" ]` / by-uuid + real NVMe modules.
3. Copied the corrected `configuration.nix` (with `hardware.graphics.enable`) over.
4. `sudo git add` both, then
   `sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-install --flake .#thinkpad-x1-carbon-g7 --no-root-passwd` (ran twice: once for the fs fix, once after the graphics fix).
5. Verified the installed config shows btrfs/subvol/by-uuid; EFI entry updated.
6. `umount -R /mnt` (clean).

Note: the machine's local clone at `/mnt/etc/nixos/nixos-dotfiles` has these as
**uncommitted** changes (its `hardware-configuration.nix` is the real
machine-specific one — do not overwrite it with the repo placeholder).

## Repo changes (this working copy — NOT committed)

- `hosts/thinkpad-x1-carbon-g7/configuration.nix` — added
  `hardware.graphics.enable = true` (in `configuration.nix` so it survives regen,
  mirroring the g12), with explanatory comment.
- `hosts/thinkpad-x1-carbon-g7/hardware-configuration.nix` (placeholder) —
  `ext4` → `btrfs` + `options = [ "subvol=@" ]`; removed the graphics line;
  updated comments. Still a by-label placeholder (regenerate per machine).
- `README.md` — added the "Continue over SSH" step; `sudo` on every
  disk/`/mnt`/system command; `sudo tee` for the hardware-config redirect; inline
  `NIX_CONFIG=` on `nixos-install`; and a ⚠️ **verification step** that greps for
  `fsType = "btrfs"` / `subvol=@` / `by-uuid` before `git add` to catch this exact
  failure.

Validated: `nixfmt` applied; `nix flake check` → **all checks passed** (both hosts).

## Pre-existing, unrelated to this session

These were already modified before the session started (left untouched except
README): `README.md` (also edited here), `home/home.nix`, `hosts/common.nix`.

## Open TODOs

- [ ] **Reboot the g7** and confirm it reaches tuigreet → Hyprland; enroll
      fingerprint (`fprintd-enroll`).
- [ ] **Commit** the repo changes (suggest a branch off `main`). Decide whether to
      also commit `home/home.nix` / `hosts/common.nix` or keep them separate.
- [ ] **Swap** (original question, deferred until it boots): add declaratively —
      btrfs swapfile needs NoCoW + no compression; verify current NixOS
      `swapDevices`/btrfs behavior before writing config. Do it on the booted
      system via `nixos-rebuild`, not in the installer.
- [ ] Reconcile the machine's locally-committed real `hardware-configuration.nix`
      vs. the repo placeholder if you ever `git pull`/reset on the g7.

## Reconnect / verify cheatsheet

Live USB SSH (only while the installer is running):
```sh
nix shell nixpkgs#sshpass --command \
  sshpass -p maxime11 ssh -o StrictHostKeyChecking=no nixos@192.168.2.31
```
After it boots, SSH targets the installed system (needs network + your user's
password); rebuild from the on-disk repo:
```sh
sudo nixos-rebuild switch --flake /etc/nixos/nixos-dotfiles#thinkpad-x1-carbon-g7
```
