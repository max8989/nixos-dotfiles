# Omarchy desktop reference

These files were copied from the installed Omarchy 4.0.0.alpha snapshot in
`omarchy-configs`, captured 2026-10-10. The resolved active theme is Tokyo Night.
The separate Jade Dark theme was present but was not active in the captured
configuration. Preserve the accompanying Omarchy MIT license when adapting or
redistributing the copied theme and capture sources.

`colors.toml`, `shell.toml`, and `kitty.conf` record the original values.
Structured settings are translated into native Nix in `home/omarchy-palette.nix`
and `home/quickshell.nix`; `btop.theme` is deployed through Home Manager.

The screenshot picker and temporary keyboard bindings are adapted from
`upstream/bin/omarchy-capture-region`, `omarchy-capture-screenshot`, and
`upstream/default/hypr/bindings/utilities.lua`. Their NixOS implementations have
explicit dependencies and no Omarchy/Arch runtime requirement.

The snapshot does not include wallpaper images, the shell QML implementation,
or its system-wide terminal defaults. The current wallpaper is retained,
Quickshell uses the captured surface tokens, and Kitty's padding is aligned with
the other captured terminals. Swappy replaces the unbundled Tensaku editor.
Neovim remains owned by the user's separate configuration repository.

Catppuccin Latte's `catppuccin-latte-colors.toml`, the `btop.theme.tpl`
template, and `home/files/backgrounds/catppuccin-latte.webp` were copied from
Omarchy's `quattro` branch on 2026-10-10. Their source paths are
`themes/catppuccin-latte/colors.toml`, `default/themed/btop.theme.tpl`, and
`themes/catppuccin-latte/backgrounds/1-color-fade.webp`. The accompanying MIT
license applies. The light wallpaper is converted to PNG at build time for
hyprpaper.

## Additional runtime themes

Osaka Jade (Omarchy's Jade theme), Catppuccin Mocha (`catppuccin`), Gruvbox and
Nord were imported on 2026-10-10 from Omarchy's `quattro` branch, pinned to
[`0b9dace01837edd87eb65f20789063abcd5cf491`](https://github.com/omacom/omarchy/tree/0b9dace01837edd87eb65f20789063abcd5cf491).
Each directory here retains byte-for-byte copies of
`themes/<id>/colors.toml`, `icons.theme` and `vscode.json`. The accompanying
Omarchy MIT license is byte-for-byte identical at that revision.

| Local wallpaper | Upstream path |
| --- | --- |
| `home/files/backgrounds/osaka-jade.webp` | `themes/osaka-jade/backgrounds/1-glowing-city.webp` |
| `home/files/backgrounds/catppuccin.webp` | `themes/catppuccin/backgrounds/1-totoro.webp` |
| `home/files/backgrounds/gruvbox.jpg` | `themes/gruvbox/backgrounds/1-the-backwater.jpg` |
| `home/files/backgrounds/nord.jpg` | `themes/nord/backgrounds/0-black-moon.jpg` |

These are the first numbered still wallpapers in each upstream theme. Source
images are preserved here and converted to PNG at build time for hyprpaper.
`kitty.conf.tpl` is copied from `default/themed/kitty.conf.tpl` at the same
revision. The existing `btop.theme.tpl` is byte-for-byte identical there.
Both templates are rendered with the original palettes, including Omarchy's
derived `selection_background = selection` and
`selection_foreground = bright_foreground` values. Qt/KDE, Quickshell, GTK,
Fcitx and TUIs map those source colors to this repository's existing assets.

VS Code uses the exact upstream descriptor names and extensions. Osaka Jade's
`jovejonovski.ocean-green` extension is pinned to the official Marketplace
VSIX version 1.1.2 with SHA-256
`sha256-sUNjnzqXya23Uieg8RLcEfnxiX0ImZ6CIjFtSJ66vM4=` in `home/omarchy.nix`.
The extension declares the MIT license. Its source manifest is available at
[`datyin/theme-ocean-green@f14d8785`](https://github.com/datyin/theme-ocean-green/blob/f14d8785bb3124907efa8a09a6a2f73fa111faf1/package.json).
The Catppuccin, Gruvbox and Nord extensions come from the pinned nixpkgs input.

## Additional light themes

Flexoki Light and White were imported on 2026-10-11 from Omarchy's `quattro`
branch at the same pinned revision,
[`0b9dace01837edd87eb65f20789063abcd5cf491`](https://github.com/omacom/omarchy/tree/0b9dace01837edd87eb65f20789063abcd5cf491).
Their directories retain byte-for-byte copies of `colors.toml` and
`icons.theme`; Flexoki Light also retains its `vscode.json`. Both palettes
declare `mode = "light"`. White omits `orange`, so the mapping uses Omarchy's
`orange = yellow` fallback from `bin/omarchy-theme-color`.

| Local wallpaper | Upstream path |
| --- | --- |
| `home/files/backgrounds/flexoki-light.webp` | `themes/flexoki-light/backgrounds/1-orb.webp` |
| `home/files/backgrounds/white.webp` | `themes/white/backgrounds/1-white.webp` |

These source images are preserved and converted to PNG at build time. The
copied Omarchy assets retain the accompanying MIT license. Qt uses recolored
Catppuccin Latte Kvantum assets for these two palettes; Catppuccin Latte keeps
its original Kvantum package. White's upstream `Yaru-grey` icon variant is
absent from the pinned nixpkgs Yaru package, so its runtime icon theme falls
back to the installed base `Yaru` set. The original descriptor remains intact.

Flexoki Light uses the exact upstream `shadesOfBuntu.flexoki-light` VS Code
extension and `flexoki-light` theme label. The official Marketplace VSIX is
pinned to version 1.0.0 with SHA-256
`sha256-//y9uvIUGGDEhd8inDHvNy2e1IKNx6hSfO9sxNOTcUE=`. Its manifest declares no
license and the archive includes no license file, so it is packaged as unfree.

White ships no `vscode.json`. Following `bin/omarchy-theme-set-vscode`, its
editor theme is generated from the byte-for-byte copy of
`default/themed/vscode-theme.json.tpl` retained here and packaged as the local
`local.omarchy-white` extension, with the distinct label `Omarchy White`.
The renderer follows Omarchy's derived selection colors, `theme_type = mode`,
orange fallback, and rounded RGB mixes used by this pinned template. The
generated extension carries Omarchy's MIT license.
