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
