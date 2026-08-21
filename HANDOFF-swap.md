# Handoff — Chrome crashes under memory pressure (swap / zram / earlyoom)

**Date:** 2026-08-20
**Host investigated:** `thinkpad-x1-carbon-g12` (Meteor Lake, 16 GB, btrfs, no LUKS)
**Status:** Diagnosed. Config patch drafted below, **not applied**. Three decisions open.

---

## 1. The symptom

Under load, Chrome tabs die en masse, the desktop becomes unusable, and a reboot is
the fastest way out. Feels like a CPU problem. It is not — CPU is idle.

## 2. Root cause chain

**Zero swap.** No swap partition, no zram. Nothing in the flake configures either;
`grep -rniE 'zram|swap' --include='*.nix'` finds only the `swappy` screenshot tool.
Neither host's `disko.nix` declares a swap volume.

```
MemTotal:     15871428 kB   (15.1 GiB)
SwapTotal:           0 kB
Committed_AS: 33864432 kB   (33 GiB promised against 15.1 GiB physical)
```

**earlyoom runs with stock defaults** — `hosts/common.nix:164`. Generated unit:

```
EARLYOOM_ARGS=-m10 -r3600 -s10
```

The kill rule is `free RAM < 10%` **AND** `free swap < 10%`. Swap is `0 of 0 MiB
(0.00%)`, so the swap condition is *permanently satisfied*. The whole thing collapses
to a single RAM trigger:

| trigger | threshold | on this machine |
|---|---|---|
| SIGTERM (`-m10`) | 10% of MemTotal | **1550 MiB available** |
| SIGKILL (auto-half) | 5% | **775 MiB available** |

**Chrome is the designated victim, not the cause.** Chrome deliberately sets
`oom_score_adj=300` on every renderer so it gets sacrificed before the kernel picks
something worse. earlyoom kills the highest `oom_score`, so Chrome wins every time:

```
earlyoom[828]: sending SIGTERM to process 554080 uid 1000 "chrome":
  oom_score 892, oom_score_adj 300, VmRSS 601 MiB, ... --type=renderer
```

Seven-day tally: **300 SIGTERMs** — 124 `chrome`, 11 `Isolated Web Co` (Zen),
9 `Web Content`. Two escalated to SIGKILL (got under 775 MiB).

The memory is actually consumed by 5 × Claude Code, Zen, Obsidian, Docker, localsend.

**Why the whole desktop dies.** With no swap the kernel's only reclaim path is
dropping page cache — which is where mmap'd `/nix/store` executables live. It evicts
the code of running programs, they fault it straight back off NVMe, repeat. Classic
no-swap refault thrash. PSI confirms it is I/O-bound, not CPU-bound:

```
memory: full avg300=0.04
cpu:    some avg300=0.00
io:     full avg300=2.18    <- 50x everything else
```

**Why the reboot.** Nothing hard-locks. The Aug 20 12:16 event was a clean
user-initiated systemd reboot. But 12:14:56 -> 12:16:18 shows earlyoom firing ~8
times in 80 s: kill renderers -> every tab "Aw, Snap" -> reload -> re-allocate ->
back under threshold -> repeat. Rebooting is just the fastest exit from the loop.

**Bonus:** `systemd-oomd` is also running and logged
`No swap; memory pressure usage will be degraded`. It is inert — its swap policy
needs swap, its pressure policy needs `ManagedOOMMemoryPressure` set on a slice
(currently `auto` = off). Two OOM daemons, one functional.

---

## 3. The plan: two-tier swap

**zram never removes anything from RAM.** A page swapped to zram is still resident,
just ~3:1 compressed. Effective capacity goes to ~20 GiB and stops there. A page
cold for eight hours still costs a compressed copy forever.

**Disk swap is the only thing that genuinely evicts.** Page goes to NVMe, RAM freed.

This workload needs both — several GB is genuinely cold:

| | RSS |
|---|---|
| 5 x `.claude-wrapped` (mostly idle) | ~2.3 GB |
| `.codex-wrapped` | 371 MB |
| Obsidian (electron x2) | ~600 MB |
| `localsend_app` | 210 MB |
| dockerd + containerd | - |

---

## 4. Verified facts about btrfs swapfiles (do not re-research)

The usual btrfs landmine is **already handled by nixpkgs**.
`nixos/modules/config/swap.nix:300`:

```bash
if [[ "$(stat -f -c %T "$(dirname "$DEVICE")")" == "btrfs" ]]; then
  rm -f "$DEVICE"
  btrfs filesystem mkswapfile --size "${size}M" --uuid clear "$DEVICE"
```

`btrfs filesystem mkswapfile` creates the file already NODATACOW and uncompressed.
**No manual `chattr +C`**, no conflict with the `compress=zstd` mount option on `@`.

**Gotcha found:** `mkdir -p "$(dirname "$DEVICE")"` exists only in the *non*-btrfs
branch. `/swap` does not exist on this machine, and the unit sets
`DefaultDependencies = false`, so it has no ordering guarantee against
`systemd-tmpfiles-setup`. **Fix: put the file at `/swapfile`** in the root of `@` —
no directory needed, no race. (`unitConfig.RequiresMountsFor` resolves to `/`, which
is always mounted.)

**No snapshot tooling** (`snapper`/`btrbk` absent, no `/.snapshots`), so the other
classic problem — btrfs refusing to snapshot a subvolume holding active swap — does
not apply. Layout is a single `@` subvolume.

Option names verified against the nixpkgs in-store source
(`/nix/store/3a2vdn5i7vd2wl654xs8nb52jf1v6cbh-source`):
- `zramSwap.{enable,memoryPercent,algorithm,priority,swapDevices,memoryMax,writebackDevice}`
  — defaults: `memoryPercent=50`, `algorithm="zstd"`, `priority=5`.
- `zramSwap.enableRecommendedSysctlSettings` **does not exist** in this revision.
  Sysctls must be set by hand.
- `swapDevices.*.{device,label,size,priority,randomEncryption,discardPolicy,options}`.
  `size` is in **MiB**.
- `services.earlyoom.{freeMemThreshold,freeMemKillThreshold,freeSwapThreshold,
  freeSwapKillThreshold,enableNotifications,killHook,reportInterval,extraArgs}`.
  `enableNotifications` pulls in `services.systembus-notify` via `mkDefault`.

---

## 5. The patch (drafted, NOT applied)

All of this goes in `hosts/common.nix`. **It is the shared module — it lands on the
g7 too.**

```nix
# Two-tier swap. zram is the hot tier: compressed pages that stay resident,
# so it raises effective capacity but never actually frees a page. The disk
# tier is the only thing that genuinely evicts cold anonymous memory (idle
# agent sessions, Electron apps untouched for hours) out of RAM. Priority
# picks the order — zram fills first, disk takes only the overflow.
zramSwap = {
  enable = true;
  memoryPercent = 50; # ~7.6G device on the g12's 15.1G
  algorithm = "zstd";
  priority = 100;
};

# btrfs swapfile. The nixpkgs swap module detects btrfs and builds this with
# `btrfs filesystem mkswapfile`, which sets NODATACOW and skips compression
# for us. Kept at / rather than /swap/: the btrfs branch of that module does
# not mkdir the parent, and its unit has DefaultDependencies=false so it is
# not ordered after systemd-tmpfiles.
swapDevices = [
  {
    device = "/swapfile";
    size = 8 * 1024; # MiB
    priority = 0; # below zram
  }
];

boot.kernel.sysctl = {
  "vm.swappiness" = 180; # swapping to zram is cheap; prefer it over cache eviction
  "vm.page-cluster" = 0; # zram is random-access, readahead is waste
  "vm.watermark_boost_factor" = 0;
  "vm.watermark_scale_factor" = 125;
};

# Fire with more headroom than the stock 10%/5% — on 15.1G that is only
# 1550/775 MiB, already past the point of no return.
services.earlyoom = {
  enable = true;
  freeMemThreshold = 15;
  freeMemKillThreshold = 8;
  enableNotifications = true; # see the kill instead of guessing
};
```

**Why 8 GB and not more:** 417 GB is free, so size is not the constraint — restraint
is. Without hibernation an oversized disk swap just means the machine thrashes
*longer* before earlyoom rescues it.

**Useful side effect:** once swap exists, earlyoom's `-s` gate stops being a no-op.
It will only kill when free RAM *and* free swap are both low, which by itself ends
most of the Chrome scapegoating — independent of the extra headroom.

---

## 6. Open decisions (these are why this is a handoff, not a commit)

1. **Hibernation — recommendation: skip.** Kernel supports it
   (`/sys/power/disk` offers `shutdown`; `/sys/power/state` includes `disk`), and
   today only `systemctl suspend` is wired up (`home/desktop.nix:257`). But
   hibernating to a *btrfs swapfile* needs `boot.resumeDevice` plus a
   `resume_offset` kernel param derived from the file's physical extent — and that
   offset changes every time the swapfile is recreated, which the mkswap service
   does whenever `size` changes. Fragile, and would need swap >= 16 GB.

2. **Unencrypted disk.** `lsblk` shows `nvme0n1p2` as btrfs directly — no LUKS. A
   swapfile writes raw RAM contents to persistent storage: decrypted Bitwarden
   vault, SSH agent keys, session tokens. Files at rest are already exposed so this
   is not a new category, but RAM contents are qualitatively worse.
   `swapDevices.*.randomEncryption.enable` would fix the at-rest leak with a fresh
   random key each boot. **Untested against the auto-created-swapfile path** — it
   layers `cryptsetup plainOpen` + a second `mkswap` on top of the `mkswapfile`
   output. Verify before trusting.

3. **g7 blast radius.** `memoryPercent` scales automatically; the 8 GB swapfile is
   absolute. The g7's free disk space was **not checked**.

---

## 7. Apply + verify

```sh
nixfmt hosts/common.nix
nix flake check                                              # checks both hosts
sudo nixos-rebuild switch --flake .#thinkpad-x1-carbon-g12
```

Should take effect live, no reboot needed. Then:

```sh
swapon --show          # expect zram0 prio 100 and /swapfile prio 0
zramctl
systemctl status mkswap-swapfile.service
sysctl vm.swappiness vm.page-cluster
systemctl cat earlyoom | grep EARLYOOM_ARGS   # expect -m15,8 -s10 -r3600 -n
```

Then watch for a week — the number that matters:

```sh
journalctl -u earlyoom --since '7 days ago' | grep -c SIGTERM   # baseline: 300
```

**Rollback:** revert the `hosts/common.nix` hunk and rebuild. `/swapfile` is left
behind on disk; `sudo swapoff /swapfile && sudo rm /swapfile` to reclaim the 8 GB.

## 8. Re-gather the evidence

```sh
swapon --show; grep -E 'MemTotal|MemAvailable|SwapTotal|Committed_AS' /proc/meminfo
cat /proc/pressure/{memory,cpu,io}
systemctl cat earlyoom | grep EARLYOOM_ARGS
journalctl -u earlyoom --since '7 days ago' | grep -oE '"[^"]+"$' | sort | uniq -c | sort -rn
ps -eo pid,comm,rss,pmem --sort=-rss | head -20
```
