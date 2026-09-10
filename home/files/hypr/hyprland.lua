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

-- NOTE: hyprpaper, hypridle, waybar and swaync are Home Manager systemd user
-- services (see desktop.nix / waybar.nix) bound to graphical-session.target.
-- Do NOT start them here as well or you get two of each — swaync especially:
-- its package ships a D-Bus-activated unit, so a hook-started instance races
-- the systemd one at login and one of the two always fails.
--
-- Home Manager also emits its own hyprland.start hook that runs
-- dbus-update-activation-environment and starts hyprland-session.target, so
-- that is deliberately absent below too.
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor catppuccin-frappe-dark-cursors 28")
    hl.exec_cmd("@polkitAgent@")
    hl.exec_cmd("swayosd-server")
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
            -- Hyprland-signature cyan→green gradient; borderangle below slowly rotates it.
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
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

    -- Tab strip drawn above a grouped window (SUPER+G groups; see keybindings.lua).
    --
    -- Upstream defaults leave the titles unreadable: `gradients` is false, and
    -- CHyprGroupBarDecoration only draws a background plate behind a tab when
    -- it is true, so the title texture lands straight on the wallpaper with no
    -- backing -- 8px light-grey text over whatever happens to be behind it.
    --
    -- So the plate has to be on. The styling then follows the Waybar islands
    -- (home/files/waybar/style.css): dark translucent glass, individually
    -- rounded, blurred. Deliberately restrained -- this strip sits directly
    -- under a bar that already carries the desktop's accent colour, and a
    -- second saturated band right below it just fights with it. The focused
    -- tab is marked the way a browser marks one: a lighter plate and brighter,
    -- heavier text, not a slab of colour.
    group = {
        groupbar = {
            -- The fix. Without this nothing below about col.* is even drawn.
            gradients = true,
            -- Plates are translucent, so frost what shows through -- same
            -- treatment the Waybar islands get from their layer rule.
            blur = true,

            -- Keep in sync with `font` in home/desktop.nix -- this is a
            -- fontconfig family name, so it cannot be shared from there
            -- (hyprland.lua only gets the @polkitAgent@ substitution). Empty
            -- would fall back to misc:font_family.
            font_family = "CaskaydiaCove Nerd Font",
            font_size = 11,           -- was 8
            font_weight_active = 600, -- the focused tab leads on weight...
            font_weight_inactive = 400,

            -- Title texture is font_size + 4 tall (BAR_TEXT_PAD = 2 a side),
            -- so 20 leaves a few px around a 15px title.
            height = 20,      -- was 14
            text_padding = 10,-- keep titles off the plate edges
            gaps_in = 4,      -- separate the tabs into distinct pills
            gaps_out = 3,

            -- Round every tab, not just the two ends of the strip. Hyprland
            -- defaults gradient_round_only_edges to true, which fuses the tabs
            -- into one long bar with rounded caps; false gives the row of
            -- separate pills the Waybar islands use.
            gradient_rounding = 8,
            gradient_round_only_edges = false,

            -- No accent underline. The indicator takes its colour from the
            -- *first* stop of col.active, so it cannot be a bright accent
            -- without dragging the whole plate bright with it -- and the
            -- lighter plate plus bolder text already says "focused".
            indicator_height = 0,

            -- ...and on brightness. Both stay well clear of the dim grey that
            -- made these unreadable to begin with; inactive is subordinate,
            -- not invisible.
            text_color = 0xffe6f4ff,
            -- Explicit because -1 (the default) means "reuse text_color".
            text_color_inactive = 0xff8296a8,
            col = {
                -- Desaturated teal-navy: clearly lighter than the inactive
                -- plate, without reading as a coloured band.
                active = { colors = { "rgba(1d3a4ce0)", "rgba(0e1a26e0)" }, angle = 45 },
                -- 0.70 alpha over the Waybar island background colour.
                inactive = "rgba(0a0a12b3)",
            },
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

-- Smart gaps, inverted: a workspace holding exactly one tiled window gets fat
-- side padding instead of none, so a lone window sits centred as a column
-- rather than filling the whole screen. `w[tv1]` = "exactly 1 tiled+visible
-- window"; `s[false]` keeps the special/scratchpad workspace out of it. As soon
-- as a second window opens the selector stops matching and the normal 10px gaps
-- come back, so tiling behaves exactly as before.
--
-- gaps_out here is a *directional* css_gaps value. Under the Lua backend that
-- must be a table of named sides -- a "10 200 10 200" string silently parses to
-- ~2px, and a positional { 10, 200, 10, 200 } list is read as a single value.
-- Left/right 200 gives 1516x1137 on the 1920x1200 panel (a tidy 4:3); raise
-- them to squeeze the window further, lower them to let it breathe wider.
hl.workspace_rule({
    workspace = "w[tv1]s[false]",
    gaps_out  = { top = 10, right = 10, bottom = 10, left = 10 },
})

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
