-- Hyprland configuration (Lua).
--
-- Deployed by home/hyprland.nix as `extraConfig`, which Home Manager appends
-- to the generated ~/.config/hypr/hyprland.lua. Keybindings live in
-- keybindings.lua, wired in via `extraLuaFiles` (Home Manager emits the
-- package.path setup and the `require("keybindings")` call itself, so this
-- file must NOT require it).
--
-- The polkit agent placeholder below is substituted with a Nix store path at
-- build time — see home/hyprland.nix. Do not hard-code /usr paths here;
-- nothing outside the Nix store exists on NixOS.
--
-- Docs: https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------

-- See all monitors: hyprctl monitors all
hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@60", position = "auto-right", scale = 1 })
hl.monitor({ output = "DP-1", mode = "1920x1080@60", position = "auto-left", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "auto-left", scale = 1 })

-- Virtual display for Sunshine game streaming
-- Activate with: hyprctl output create headless SUNSHINE
hl.monitor({ output = "SUNSHINE", mode = "1280x720@30", position = "auto", scale = 1 })

-------------------
---- AUTOSTART ----
-------------------

-- NOTE: hyprpaper, hypridle and waybar are Home Manager systemd user services
-- (see desktop.nix / waybar.nix) bound to graphical-session.target. Do NOT
-- start them here as well or you get two of each.
--
-- Home Manager also emits its own hyprland.start hook that runs
-- dbus-update-activation-environment and starts hyprland-session.target, so
-- that is deliberately absent below too.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor catppuccin-frappe-dark-cursors 28")
    hl.exec_cmd("@polkitAgent@")
    hl.exec_cmd("swaync & swayosd-server")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")  -- text only
    hl.exec_cmd("wl-paste --type image --watch cliphist store") -- images only
    hl.exec_cmd("kanata --cfg ~/.config/kanata/config.kbd")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            -- Omarchy cyan-green gradient
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 6,
        rounding_power = 1,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 2,
            render_power = 3,
            color        = 0xee1a1a1a, -- rgba(1a1a1aee) as ARGB
        },

        blur = {
            enabled    = false,
            size       = 2,
            passes     = 2,
            brightness = 0.60,
            contrast   = 0.75,
            vibrancy   = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Omarchy bezier curves
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },   { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0 },   { 0.35, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },      { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },  { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },   { 0.1, 1 } } })

-- Smooth window animations
hl.animation({ leaf = "windows",     enabled = true,  speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",   enabled = true,  speed = 4.1,  bezier = "easeOutQuint",  style = "popin 87%" })
hl.animation({ leaf = "windowsOut",  enabled = true,  speed = 1.49, bezier = "linear",        style = "popin 87%" })
hl.animation({ leaf = "windowsMove", enabled = true,  speed = 2.5,  bezier = "easeInOutCubic" })
hl.animation({ leaf = "fade",        enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "fadeIn",      enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",     enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fadeSwitch",  enabled = false, speed = 1,    bezier = "easeInOutCubic" })
hl.animation({ leaf = "fadeShadow",  enabled = true,  speed = 10,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeDim",     enabled = true,  speed = 4.03, bezier = "almostLinear" })
hl.animation({ leaf = "border",      enabled = true,  speed = 0.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "borderangle", enabled = true,  speed = 0.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces",  enabled = true,  speed = 0.8,  bezier = "easeOutQuint",  style = "slidefade" })
hl.animation({ leaf = "layers",      enabled = true,  speed = 3.81, bezier = "easeOutQuint",  style = "fade" })
hl.animation({ leaf = "layersIn",    enabled = true,  speed = 4,    bezier = "easeOutQuint",  style = "fade" })
hl.animation({ leaf = "layersOut",   enabled = true,  speed = 1.5,  bezier = "linear",        style = "fade" })

-- "Smart gaps" / "No gaps when only" -- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })

hl.config({
    dwindle = {
        preserve_split = true, -- You probably want this
        force_split    = 2,    -- Always split to the right/bottom like i3
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "us,ca",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:ctrl_space_toggle",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Example per-device config
hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })
