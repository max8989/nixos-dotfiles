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
--
-- Catch-all for any display without a rule of its own.
hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1 })

-- Per-display rules are keyed on the EDID description (`desc:` prefix), NOT on
-- the connector, so a monitor keeps its settings whichever port it lands on.
-- The dock hands out DP-1..DP-4 in whatever order it feels like, which is why
-- the old per-connector rules (DP-1/DP-2/DP-3/HDMI-A-1) were four guesses at
-- the same physical monitor.
--
-- The string is the `description:` line from `hyprctl monitors`, up to but not
-- including the portname. Dropping the trailing serial makes it match any unit
-- of that model instead of this exact one.
local GIGABYTE_G24F = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. G24F 2 22450B007095"
hl.monitor({ output = "DP-1", mode = "1920x1080@60", position = "auto-left", scale = 1 })
hl.monitor({ output = GIGABYTE_G24F, mode = "2560x1440@60", position = "auto-left", scale = 1 })

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
end)
-- NOTE: kanata is deliberately absent — it runs as a systemd user service on
-- default.target (see home/hyprland.nix) so it survives a compositor restart
-- and does not depend on this config parsing at all.

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
            -- Neon blue→cyan gradient; borderangle below slowly rotates it.
            active_border   = { colors = { "rgba(3366ffee)", "rgba(33ccffee)" }, angle = 45 },
            inactive_border = "rgba(1a1f2eaa)",
        },

        resize_on_border = false,
        allow_tearing    = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        -- Focus pop: slightly dim whatever isn't focused.
        dim_inactive = true,
        dim_strength = 0.08,

        shadow = {
            enabled      = true,
            range        = 3,
            render_power = 3,
            color        = 0x1033ccff, -- barely-there cyan tint under the active window (ARGB)
        },

        blur = {
            enabled    = true,
            size       = 8,
            passes     = 2,
            brightness = 0.80,
            contrast   = 0.90,
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
hl.curve("overshot",       { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } }) -- slight bounce past the target

-- Smooth window animations
hl.animation({ leaf = "windows",     enabled = true,  speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",   enabled = true,  speed = 4.1,  bezier = "overshot",      style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true,  speed = 1.49, bezier = "linear",        style = "popin 87%" })
hl.animation({ leaf = "windowsMove", enabled = true,  speed = 2.5,  bezier = "overshot" })
hl.animation({ leaf = "fade",        enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "fadeIn",      enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",     enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fadeSwitch",  enabled = false, speed = 1,    bezier = "easeInOutCubic" })
hl.animation({ leaf = "fadeShadow",  enabled = true,  speed = 10,   bezier = "almostLinear" })
hl.animation({ leaf = "fadeDim",     enabled = true,  speed = 4.03, bezier = "almostLinear" })
hl.animation({ leaf = "border",      enabled = true,  speed = 0.81, bezier = "easeOutQuint" })
-- Slow continuous rotation of the cyan→green border gradient. NOTE: `loop`
-- keeps the compositor rendering at refresh rate — speed 100 (10 s/turn)
-- keeps the cost low; disable this line first if battery life matters more.
hl.animation({ leaf = "borderangle", enabled = true,  speed = 100,  bezier = "linear",        style = "loop" })
hl.animation({ leaf = "workspaces",  enabled = true,  speed = 0.8,  bezier = "easeOutQuint",  style = "slidefade" })
-- Special workspace (SUPER+S scratchpad): same slidefade as before, but with
-- the overshot curve so it bounces into place like moving windows do.
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "overshot", style = "slidefade" })
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

---------------------
---- LAYER RULES ----
---------------------

-- Glassy blur for the shell surfaces. ignore_alpha keeps fully-transparent
-- regions (the gaps between waybar's three islands) from being blurred —
-- the threshold must sit below each surface's background alpha.
hl.layer_rule({ match = { namespace = "waybar" },                      blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "wofi" },                        blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "rofi" },                        blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "swaync-control-center" },       blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "swaync-notification-window" },  blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "swayosd" },                     blur = true, ignore_alpha = 0.35 })
hl.layer_rule({ match = { namespace = "wlogout" },                     blur = true, ignore_alpha = 0.2 })

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
