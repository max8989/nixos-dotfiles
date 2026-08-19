-- Keybindings (Lua).
--
-- Deployed by home/hyprland.nix via `extraLuaFiles`, which writes this to
-- ~/.config/hypr/keybindings.lua and emits the `require("keybindings")` call
-- in the generated hyprland.lua.
--
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Programs
local editor      = "zed"
local terminal    = "kitty"
local fileManager = "superfile" -- TUI file manager; nixpkgs names the binary
                                -- `superfile`, Arch's AUR package called it `spf`
local menu        = "pidof rofi && killall rofi || rofi -show drun"
local browser     = "zen-browser"
local screenshot  = "~/.config/scripts/screenshot.sh"

-- Application shortcuts
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal), { description = "launch terminal emulator" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " -e " .. fileManager), { description = "launch file manager" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(terminal .. " -e btop"))

-- Rofi menus
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind("ALT + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd('rofi -show fb -modi "fb:~/.config/scripts/rofi-fb-official.sh"'))

-- NOTE: no wallpaper switcher (was SUPER+CTRL+W). The script rewrote
-- ~/.config/hypr/hyprpaper.conf, which Home Manager makes a read-only Nix
-- store symlink, so it could never work here. Change the wallpaper by editing
-- services.hyprpaper in home/desktop.nix and rebuilding.

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(
    'pidof rofi && killall rofi || cliphist list | rofi -dmenu -window-title "Clipboard" -drun-use-desktop-cache | cliphist decode | wl-copy'))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + C", hl.dsp.window.float({ action = "toggle" }))

-- Resize floating window with mainMod + Ctrl + Mouse movement
hl.bind(mainMod .. " + CTRL + mouse_down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }))
hl.bind(mainMod .. " + CTRL + mouse_up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }))
hl.bind(mainMod .. " + CTRL + mouse_right", hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }))
hl.bind(mainMod .. " + CTRL + mouse_left",  hl.dsp.window.resize({ x = -30, y = 0,   relative = true }))

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())                                      -- dwindle
hl.bind(mainMod .. " + U", hl.dsp.layout("togglesplit"))                                -- dwindle
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + D", hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))

-- Grouped (i3-style tabbed) windows
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + Tab", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.group.prev())
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))

-- Vim Helper
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd(
    "cat ~/.config/rofi/vimcheat | rofi -dmenu -p \"Vim action\" -i -theme-str 'window {width: 98%; height: 75%;}' -theme-str 'window {location: center;}'"))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(
    "cat ~/.config/rofi/lazyvimcheat | rofi -dmenu -p \"LazyVim action\" -i -theme-str 'window {width: 98%; height: 75%;}' -theme-str 'window {location: center;}'"))

-- Move focus with mainMod + arrow keys / vim keys
local focusDirs = { left = "left", right = "right", up = "up", down = "down", h = "left", l = "right", k = "up", j = "down" }
for key, dir in pairs(focusDirs) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end

-- Print Screen & Screen Record
hl.bind("ALT + 1", hl.dsp.exec_cmd(screenshot .. " -m region -z"))
hl.bind("ALT + 2", hl.dsp.exec_cmd(screenshot .. " -m active -m window -z"))
hl.bind("ALT + 3", hl.dsp.exec_cmd(screenshot .. " -m active -m output -z"))
hl.bind("ALT + 4", hl.dsp.exec_cmd("~/.config/scripts/screen_record.sh"))

-- Power menu
hl.bind(mainMod .. " + n", hl.dsp.exec_cmd("~/.config/waybar/scripts/power-menu.sh"))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))
end

-- Move active window to relative / empty workspaces
local moveWs = {
    Right = "r+1", Left = "r-1", Down = "empty",
    l     = "r+1", h    = "r-1", k    = "empty",
}
for key, ws in pairs(moveWs) do
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Navigate workspaces on the current monitor (arrows + vim keys)
-- m-1/m+1: prev/next on monitor, emptynm: next empty on monitor, m~1: first on monitor
local navWs = {
    left = "m-1", right = "m+1", down = "emptynm", up = "m~1",
    h    = "m-1", l     = "m+1", k    = "emptynm", j  = "m~1",
}
for key, ws in pairs(navWs) do
    hl.bind("CTRL + ALT + " .. key, hl.dsp.focus({ workspace = ws }))
end

-- Resize window with mainMod + ALT + arrow keys / vim keys
local resizeDirs = {
    left = { -50, 0 }, right = { 50, 0 }, up = { 0, -50 }, down = { 0, 50 },
    h    = { -50, 0 }, l     = { 50, 0 }, k  = { 0, -50 }, j    = { 0, 50 },
}
for key, d in pairs(resizeDirs) do
    hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.resize({ x = d[1], y = d[2], relative = true }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Move the active window, or insert it into a neighboring group (arrows + vim keys)
-- NOTE: SUPER+SHIFT+Up/Down are re-bound to mic volume further down, matching the
-- original keybindings.conf ordering.
local moveOrGroup = {
    left = "left", right = "right", up = "up", down = "down",
    h    = "left", l     = "right", k  = "up", j    = "down",
}
for key, dir in pairs(moveOrGroup) do
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir, group_aware = true }))
end

hl.bind("CTRL + ALT + space", hl.dsp.exec_raw("fcitx5-remote -t"))

-- NOTE: there is no Alt-Tab bind here on purpose. The switcher is hyprshell
-- (successor to hyprswitch), configured in home/desktop.nix as
-- `services.hyprshell`. It grabs ALT+TAB itself over Hyprland's
-- global-shortcuts protocol, so a bind in this file would only fight it.

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_right", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_left",  hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "hold to move window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "hold to resize window" })
hl.bind(mainMod .. " + Z", hl.dsp.window.drag(),   { mouse = true, description = "hold to move window" })
hl.bind(mainMod .. " + X", hl.dsp.window.resize(), { mouse = true, description = "hold to resize window" })

-- Laptop multimedia keys for volume and LCD brightness with SwayOSD
local osd = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise --max-volume 150"), osd)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower --max-volume 150"), osd)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), osd)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle"), osd)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise"), osd)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower --min-brightness 0"), osd)

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Microphone volume control
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind(mainMod .. " + SHIFT + Up",   hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+"), { locked = true, repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-"), { locked = true, repeating = true })

-- Audio output selector (rofi menu; replaces hyprwat, which is AUR-only and
-- not packaged for NixOS)
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("~/.config/waybar/scripts/audio-menu.sh"))

-- Close rofi menus on any left click outside them (rofi 2.0's wayland
-- backend can't see clicks outside its own surface). Non-consuming: the
-- click still reaches whatever was clicked. The script skips clicks inside
-- waybar, whose module scripts toggle rofi themselves.
hl.bind("mouse:272", hl.dsp.exec_cmd("~/.config/scripts/rofi-close-outside.sh"), { non_consuming = true })
