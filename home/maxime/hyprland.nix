{
  inputs,
  pkgs,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Same Hyprland package the system enables (from the flake input).
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    settings = {
      ###################################################################
      ## Variables (from keybindings.conf)
      ###################################################################
      "$mainMod" = "SUPER";
      "$mod" = "alt";
      "$editor" = "zed";
      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
      "$browser" = "zen-browser";
      "$menu" = "pidof rofi && killall rofi || rofi -show drun";
      "$screenshot" = "~/.config/scripts/screenshot.sh";

      # --- monitors (from hyprland.conf) ---
      monitor = [
        ",highres,auto,1"
        "DP-2,2560x1440@60,auto-right,1"
        "DP-1,1920x1080@60,auto-left,1"
        "SUNSHINE,1280x720@30,auto,1"
      ];

      # --- environment ---
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      # --- autostart ---
      # hyprpaper, hypridle and waybar are managed by Home Manager systemd user
      # services (see desktop.nix / waybar.nix), so they are NOT launched here.
      # exec-once only covers daemons without an HM service module + the polkit
      # agent (nix store path) and cliphist watchers.
      exec-once = [
        "hyprctl setcursor catppuccin-frappe-dark-cursors 28"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "swaync & swayosd-server"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "kanata --cfg ~/.config/kanata/config.kbd"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 6;
        rounding_power = 1;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        shadow = {
          enabled = true;
          range = 2;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
        blur = {
          enabled = false;
          size = 2;
          passes = 2;
          brightness = 0.60;
          contrast = 0.75;
          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "easeInOutCubic, 0.65, 0, 0.35, 1"
          "linear, 0, 0, 1, 1"
          "almostLinear, 0.5, 0.5, 0.75, 1.0"
          "quick, 0.15, 0, 0.1, 1"
        ];
        animation = [
          "windows, 1, 4.79, easeOutQuint"
          "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
          "windowsOut, 1, 1.49, linear, popin 87%"
          "windowsMove, 1, 2.5, easeInOutCubic"
          "fade, 1, 3.03, quick"
          "fadeIn, 1, 1.73, almostLinear"
          "fadeOut, 1, 1.46, almostLinear"
          "fadeSwitch, 0, 1, easeInOutCubic"
          "fadeShadow, 1, 10, almostLinear"
          "fadeDim, 1, 4.03, almostLinear"
          "border, 1, 0.81, easeOutQuint"
          "borderangle, 1, 0.81, easeOutQuint"
          "workspaces, 1, 0.8, easeOutQuint, slidefade"
          "layers, 1, 3.81, easeOutQuint, fade"
          "layersIn, 1, 4, easeOutQuint, fade"
          "layersOut, 1, 1.5, linear, fade"
        ];
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
      };

      master.new_status = "master";

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
      };

      input = {
        kb_layout = "us,ca";
        kb_options = "grp:ctrl_space_toggle";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad.natural_scroll = true;
      };

      gesture = "3, horizontal, workspace";

      device = {
        name = "epic-mouse-v1";
        sensitivity = -0.5;
      };

      ###################################################################
      ## Keybindings (inlined from keybindings.conf)
      ###################################################################
      bind = [
        # Applications
        "$mainMod, return, exec, $terminal"
        "$mainMod, E, exec, $fileManager"
        "Ctrl+Alt, Delete, exec, $terminal -e btop"

        # Rofi menus
        "$mainMod, A, exec, $menu"
        "$mod, space, exec, $menu"
        ''$mainMod, B, exec, rofi -show fb -modi "fb:~/.config/scripts/rofi-fb-official.sh"''
        "$mainMod, Space, exec, $menu"
        ''$mainMod, V, exec, pidof rofi && killall rofi || cliphist list | rofi -dmenu -window-title "Clipboard" -drun-use-desktop-cache | cliphist decode | wl-copy''

        # Wallpaper switcher
        "$mainMod CTRL, W, exec, ~/.config/scripts/wallpaper-switcher.sh"

        # Window management
        "$mainMod, Q, killactive,"
        "$mainMod, C, togglefloating,"
        "$mainMod, P, pseudo,"
        "$mainMod, U, layoutmsg, togglesplit"
        "$mainMod, F, fullscreen,"
        "$mainMod, D, fullscreen, 1"

        # Resize floating window with mainMod + Ctrl + Mouse
        "$mainMod CTRL, mouse_down, resizeactive, 0 30"
        "$mainMod CTRL, mouse_up, resizeactive, 0 -30"
        "$mainMod CTRL, mouse_right, resizeactive, 30 0"
        "$mainMod CTRL, mouse_left, resizeactive, -30 0"

        # Vim / LazyVim cheatsheets
        ''$mainMod, slash, exec, cat ~/.config/rofi/vimcheat | rofi -dmenu -p "Vim action" -i -theme-str 'window {width: 98%; height: 75%;}' -theme-str 'window {location: center;}' ''
        ''$mainMod, period, exec, cat ~/.config/rofi/lazyvimcheat | rofi -dmenu -p "LazyVim action" -i -theme-str 'window {width: 98%; height: 75%;}' -theme-str 'window {location: center;}' ''

        # Move focus — arrows
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        # Move focus — vim
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"

        # Screenshots / screen record
        "alt, 1, exec, $screenshot -m region -z"
        "alt, 2, exec, $screenshot -m active -m window -z"
        "alt, 3, exec, $screenshot -m active -m output -z"
        "alt, 4, exec, ~/.config/scripts/screen_record.sh"

        # Power menu
        "$mainMod, n, exec, ~/.config/waybar/scripts/power-menu.sh"

        # Switch workspaces
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move active window to workspace
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"
        "$mainMod CTRL, Right, movetoworkspace, r+1"
        "$mainMod CTRL, Left, movetoworkspace, r-1"
        "$mainMod CTRL, Down, movetoworkspace, empty"
        "$mainMod CTRL, l, movetoworkspace, r+1"
        "$mainMod CTRL, h, movetoworkspace, r-1"
        "$mainMod CTRL, k, movetoworkspace, empty"

        # Workspaces on current monitor — arrows
        "CTRL ALT, left, workspace, m-1"
        "CTRL ALT, right, workspace, m+1"
        "CTRL ALT, down, workspace, emptynm"
        "CTRL ALT, up, workspace, m~1"
        # Workspaces on current monitor — vim
        "CTRL ALT, h, workspace, m-1"
        "CTRL ALT, l, workspace, m+1"
        "CTRL ALT, k, workspace, emptynm"
        "CTRL ALT, j, workspace, m~1"

        # Resize window — mainMod + alt + arrows
        "$mainMod ALT, left, resizeactive, -50 0"
        "$mainMod ALT, right, resizeactive, 50 0"
        "$mainMod ALT, up, resizeactive, 0 -50"
        "$mainMod ALT, down, resizeactive, 0 50"
        # Resize window — mainMod + alt + vim
        "$mainMod ALT, h, resizeactive, -50 0"
        "$mainMod ALT, l, resizeactive, 50 0"
        "$mainMod ALT, k, resizeactive, 0 -50"
        "$mainMod ALT, j, resizeactive, 0 50"

        # Special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Move active window — arrows
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        # Move active window — vim
        "$mainMod SHIFT, h, movewindow, l"
        "$mainMod SHIFT, l, movewindow, r"
        "$mainMod SHIFT, k, movewindow, u"
        "$mainMod SHIFT, j, movewindow, d"

        # fcitx5 toggle
        "CTRL+ALT, space, execr, fcitx5-remote -t"

        # Scroll through workspaces with mainMod + scroll
        "$mainMod, mouse_right, workspace, e+1"
        "$mainMod, mouse_left, workspace, e-1"

        # Microphone mute toggle
        "$mainMod SHIFT, M, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"

        # Audio device selector (NOTE: hyprwat is not packaged on NixOS — dead until
        # packaged; see README "Known gaps". pavucontrol / wpctl cover it.)
        "$mainMod, F12, exec, hyprwat --audio"
      ];

      # Move/resize windows with description (binddm)
      binddm = [
        "$mainMod, mouse:272, $d hold to move window, movewindow"
        "$mainMod, mouse:273, $d hold to resize window, resizewindow"
        "$mainMod, Z, $d hold to move window, movewindow"
        "$mainMod, X, $d hold to resize window, resizewindow"
      ];

      # Repeat-while-held binds (volume / brightness / mic volume) — SwayOSD
      bindel = [
        ",XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise --max-volume 150"
        ",XF86AudioLowerVolume, exec, swayosd-client --output-volume lower --max-volume 150"
        ",XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ",XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
        ",XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ",XF86MonBrightnessDown, exec, swayosd-client --brightness lower --min-brightness 0"
        "$mainMod SHIFT, Up, exec, wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+"
        "$mainMod SHIFT, Down, exec, wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-"
      ];

      # Locked binds (work on lock screen) — media keys via playerctl
      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];
    };
  };

  # kanata config (referenced by the exec-once above). Carried as an in-repo
  # file — kanata's .kbd format has no Home Manager module.
  xdg.configFile."kanata/config.kbd".source = ./files/kanata/config.kbd;
}
