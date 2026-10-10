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
