# Commands

Run from the repo root (`cd ~/repos/nixos-dotfiles`).
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

### Switch desktop theme

Open **Style → Theme** with Super+M, or open the theme menu directly with
Super+Ctrl+Shift+Space. From a terminal:

```
desktop-theme list
desktop-theme current
desktop-theme set catppuccin-latte
desktop-theme set flexoki-light
desktop-theme set white
desktop-theme set osaka-jade
desktop-theme set catppuccin
desktop-theme set gruvbox
desktop-theme set nord
desktop-theme set tokyo-night
```

`catppuccin` selects Catppuccin Mocha; Omarchy names its Jade theme Osaka Jade.
The light choices are `catppuccin-latte`, `flexoki-light` and `white`.
The choice persists across rebuilds. Some applications need reopening to read
their new colors.

### Change wallpaper

Open **Style → Wallpaper** with Super+M, or press **Super+Ctrl+Space**.
The gallery has three actions:

- **Import → Choose files…** adds one or more PNG, JPEG, WebP or BMP images.
  **Choose in superfile…** opens superfile with image previews; Enter selects
  one image and Esc cancels. The last import folder is remembered.
- **Change wallpaper** applies the selected thumbnail to the current theme.
  Importing only adds images to the shared collection. Each theme remembers
  its own choice across theme switches, login and rebuilds.
- **Delete** removes an imported image from the collection after confirmation.
  The confirmation names any affected themes, which return to their defaults.
  Original source files are kept. The protected **Theme default** card can be
  applied to restore the current theme's bundled image.

Arrow keys navigate the gallery, Enter applies, Delete asks to remove, and Tab
moves between controls. Search filters saved filenames. Existing custom images
remain available; images saved before filename tracking appear as “Saved wallpaper…”.

From a terminal, omit the theme name to use the current theme, or specify one:

```
desktop-theme wallpaper set "$HOME/Pictures/wallpaper.jpg"
desktop-theme wallpaper set "$HOME/Pictures/wallpaper.jpg" nord
desktop-theme wallpaper current
desktop-theme wallpaper current nord
desktop-theme wallpaper reset
desktop-theme wallpaper reset nord
desktop-theme wallpaper import "$HOME/Downloads/photo.jpg" "$HOME/Pictures/landscape.png"
desktop-theme wallpaper library
desktop-theme wallpaper select <id> nord
desktop-theme wallpaper delete <id>
```

Choosing a wallpaper for an inactive theme leaves the current desktop as it is.
Selected images are copied into `~/.local/state/desktop-theme/wallpapers`
(or `$XDG_STATE_HOME/desktop-theme/wallpapers`), so moving the source is safe.
Hyprpaper uses a separate current-wallpaper link in this state directory.
`import` and `library` return JSON. Import reports each file as `imported`,
`duplicate`, or `error`, keeping successful imports even if another file fails
(a batch with errors exits nonzero). `select` and `delete` take an ID returned
by these commands. Terminal deletion resets every theme using that image
without an interactive prompt; the gallery supplies the confirmation.

This follows Omarchy's [background selection and theme memory](https://github.com/omacom/omarchy/blob/quattro/bin/omarchy-theme-set)
and [background picker shortcut](https://github.com/omacom/omarchy/blob/quattro/manual/39-backgrounds.md),
adapted to this desktop's immutable Nix assets and Hyprpaper service.

## Update and troubleshoot

### Update flake inputs

Afterward, check, switch, and commit `flake.lock`.

```
nix flake update
```

### Update a single flake input

Moves only that input; everything else stays pinned. Name several to update
them together.

```
nix flake update hyprland
```

There is no per-package update: almost every package comes from the one
`nixpkgs` input, so `nix flake update nixpkgs` moves all of them at once. To
advance one package alone, give it its own flake input (as `superfile` and
`zen-browser` have) and reference that in the module. An input pinned to a tag
— `superfile` is on `v1.6.0` — ignores this command; edit the tag in
`flake.nix` instead.

### Validate the desktop shell

```
nix flake check
nix build .#quickshell-vm-test --no-link
```

Restart Quickshell only while unlocked.

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
systemctl --user restart quickshell
```

### View daemon logs

```
journalctl --user -u quickshell -e
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
