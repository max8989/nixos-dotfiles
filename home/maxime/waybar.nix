{ ... }:
{
  # Waybar — launched as an HM systemd user service (graphical-session.target).
  # config.jsonc -> settings (pure Nix); the self-contained i3-style style.css
  # is carried verbatim (CSS has no attribute-set form).
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings.mainBar = {
      layer = "top";
      position = "top";
      mode = "dock";
      reload_style_on_change = true;
      gtk-layer-shell = true;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [
        "clock"
        "custom/reminders"
      ];
      modules-right = [
        "custom/cpu"
        "custom/memory"
        "network"
        "pulseaudio"
        "custom/mic"
        "idle_inhibitor"
        "power-profiles-daemon"
        "battery"
        "hyprland/language"
        "tray"
        "custom/notification"
        "custom/power"
      ];

      "hyprland/workspaces" = {
        on-scroll-up = "hyprctl dispatch workspace -1";
        on-scroll-down = "hyprctl dispatch workspace +1";
        persistent-workspaces = {
          "1" = [ ];
        };
      };

      "hyprland/window" = {
        format = "{}";
        min-length = 5;
        rewrite = {
          "" = "Hyprland";
        };
      };

      "custom/cpu" = {
        exec = "~/.config/waybar/scripts/cpu-info.sh";
        return-type = "json";
        interval = 5;
        on-click = "kitty -e btop";
      };

      "custom/memory" = {
        exec = "~/.config/waybar/scripts/memory-info.sh";
        return-type = "json";
        interval = 5;
        on-click = "kitty -e btop";
      };

      network = {
        format = "{icon}";
        format-wifi = "{icon}";
        format-ethernet = "󰀂";
        format-disconnected = "󰤮";
        format-icons = [
          "󰤯"
          "󰤟"
          "󰤢"
          "󰤥"
          "󰤨"
        ];
        tooltip-format-wifi = "{essid} ({signalStrength}%)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
        tooltip-format-ethernet = "{ifname}\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
        tooltip-format-disconnected = "Disconnected";
        interval = 3;
        on-click = "~/.config/waybar/scripts/wifi-menu.sh";
      };

      clock = {
        format = "{:%Y-%m-%d %H:%M}";
        tooltip-format = "<tt>{calendar}</tt>";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟 {volume}%";
        format-icons = {
          headphone = "󰋋";
          headset = "󰋎";
          speaker = "󰓃";
          hdmi = "󰡁";
          default = [
            "󰕿"
            "󰖀"
            "󰕾"
          ];
        };
        tooltip = true;
        tooltip-format = "{desc} — {volume}%";
        scroll-step = 5;
        on-click = "hyprwat --audio"; # NOTE: hyprwat not packaged — see README "Known gaps"
        on-click-right = "swayosd-client --output-volume mute-toggle";
        on-scroll-up = "swayosd-client --output-volume raise";
        on-scroll-down = "swayosd-client --output-volume lower";
      };

      "custom/mic" = {
        exec = "~/.config/waybar/scripts/mic-status.sh";
        return-type = "json";
        interval = 2;
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+";
        on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
      };

      battery = {
        states = {
          warning = 20;
          critical = 10;
        };
        format = "BAT {capacity}%";
        format-charging = "CHR {capacity}%";
        tooltip = false;
        interval = 30;
      };

      power-profiles-daemon = {
        format = "{icon}";
        tooltip-format = "Power profile: {profile}\nDriver: {driver}";
        tooltip = true;
        format-icons = {
          default = "󰗑";
          performance = "󰓅";
          balanced = "󰾅";
          power-saver = "󰾆";
        };
      };

      "hyprland/language" = {
        format-en = "EN";
        format-fr = "FR";
        format-ca = "CA";
      };

      tray = {
        spacing = 10;
      };

      "custom/reminders" = {
        exec = "~/.config/waybar/scripts/reminders.sh";
        return-type = "json";
        interval = 30;
        on-click = "~/.config/waybar/scripts/reminders-popup.sh";
        tooltip = true;
      };

      "custom/notification" = {
        tooltip = false;
        format = "{icon}";
        format-icons = {
          notification = "󰂚";
          none = "󰂜";
          dnd-notification = "󰂛";
          dnd-none = "󰪑";
          inhibited-notification = "󰂚";
          inhibited-none = "󰂜";
          dnd-inhibited-notification = "󰂛";
          dnd-inhibited-none = "󰪑";
        };
        return-type = "json";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "󰅶";
          deactivated = "󰾪";
        };
        tooltip-format-activated = "Presentation mode ON — sleep inhibited";
        tooltip-format-deactivated = "Presentation mode OFF — normal idle behavior";
      };

      "custom/power" = {
        format = "⏻";
        tooltip = false;
        on-click = "~/.config/waybar/scripts/power-menu.sh";
      };
    };

    style = builtins.readFile ./files/waybar/style.css;
  };

  # Waybar module scripts (referenced by the exec/on-click paths above).
  # Carried as in-repo files; their runtime deps are on PATH via home.packages.
  xdg.configFile."waybar/scripts".source = ./files/waybar/scripts;
}
