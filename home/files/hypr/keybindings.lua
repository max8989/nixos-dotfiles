-- Keybindings (Lua).
--
-- Deployed by home/hyprland.nix via `extraLuaFiles`, which writes this to
-- ~/.config/hypr/keybindings.lua and emits the `require("keybindings")` call
-- in the generated hyprland.lua.
--
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/

local shell = require("shell_commands")
local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Settings panels (also available from Super+M and the top bar).
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd(shell.audio), { description = "audio settings" })
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd(shell.wifi), { description = "Wi-Fi settings" })
hl.bind(mainMod .. " + CTRL + D", hl.dsp.exec_cmd(shell.display), { description = "display settings" })
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd(shell.battery), { description = "battery and power profile" })

-- Programs
local editor      = "zed"
local terminal    = "kitty"
local fileManager = "superfile" -- TUI file manager; nixpkgs names the binary
                                -- `superfile`, Arch's AUR package called it `spf`
local menu        = shell.apps
local browser     = "zen-beta" -- wrapper binary name from the zen-browser flake
local screenshot  = shell.screenshot

-- Application shortcuts
hl.bind(mainMod .. " + return", hl.dsp.exec_cmd(terminal), { description = "launch terminal emulator" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(terminal .. " -e " .. fileManager), { description = "launch file manager" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(terminal .. " -e btop"))

-- Quickshell menus
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(shell.controls), { description = "desktop controls" })
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(menu))
hl.bind("ALT + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(shell.files))

-- NOTE: no wallpaper switcher (was SUPER+CTRL+W). The script rewrote
-- ~/.config/hypr/hyprpaper.conf, which Home Manager makes a read-only Nix
-- store symlink, so it could never work here. Change the wallpaper by editing
-- services.hyprpaper in home/desktop.nix and rebuilding.

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(shell.clipboard))

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

-- Searchable reference panels
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd(shell.vim))
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd(shell.lazyvim))

-- Move focus with mainMod + arrow keys / vim keys
local focusDirs = { left = "left", right = "right", up = "up", down = "down", h = "left", l = "right", k = "up", j = "down" }
for key, dir in pairs(focusDirs) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end

-- Print Screen & Screen Record
hl.bind("ALT + 1", hl.dsp.exec_cmd(screenshot .. " region"))
hl.bind("ALT + 2", hl.dsp.exec_cmd(screenshot .. " windows"))
hl.bind("ALT + 3", hl.dsp.exec_cmd(screenshot .. " fullscreen"))
hl.bind("PRINT", hl.dsp.exec_cmd(screenshot .. " smart"))
hl.bind(mainMod .. " + ALT + comma", hl.dsp.exec_cmd(shell.editScreenshot))
hl.bind("ALT + 4", hl.dsp.exec_cmd("~/.config/scripts/screen_record.sh"))

-- Power menu
hl.bind(mainMod .. " + n", hl.dsp.exec_cmd(shell.power))

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

-- Move the active window without inserting it into a neighboring group.
-- NOTE: SUPER+SHIFT+Up/Down are re-bound to mic volume further down, matching the
-- original keybindings.conf ordering.
local moveDirs = {
    left = "left", right = "right", up = "up", down = "down",
    h    = "left", l     = "right", k  = "up", j    = "down",
}
for key, dir in pairs(moveDirs) do
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))

    -- Adding a window to a tabbed group requires the more deliberate Ctrl chord.
    hl.bind(mainMod .. " + CTRL + SHIFT + " .. key, hl.dsp.window.move({ direction = dir, group_aware = true }))
end

-- us -> ca -> pinyin -> us (script steps both Hyprland's layout and fcitx5).
hl.bind("CTRL + space", hl.dsp.exec_cmd(shell.cycleInput), { description = "cycle us / ca / pinyin" })
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

-- Laptop multimedia keys for volume and LCD brightness with Quickshell
local osd = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(shell.volumeUp), osd)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(shell.volumeDown), osd)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(shell.mute), osd)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(shell.muteMicrophone), osd)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(shell.brightnessUp), osd)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(shell.brightnessDown), osd)

-- MPRIS controls
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(shell.mediaNext),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(shell.mediaToggle), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(shell.mediaToggle), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(shell.mediaPrevious),   { locked = true })

-- Microphone volume control
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(shell.muteMicrophone))
hl.bind(mainMod .. " + SHIFT + Up",   hl.dsp.exec_cmd(shell.microphoneUp), { locked = true, repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.exec_cmd(shell.microphoneDown), { locked = true, repeating = true })

-- Audio output selector
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd(shell.audio))
