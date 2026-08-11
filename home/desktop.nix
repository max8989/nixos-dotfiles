{ pkgs, ... }:
let
  font = "CaskaydiaCove Nerd Font";
in
{
  # Daemons without an HM service module (launched from Hyprland exec-once) +
  # the polkit agent. hyprlock/hypridle/hyprpaper packages come from their HM
  # modules below.
  home.packages = with pkgs; [
    swaynotificationcenter # `swaync` / `swaync-client`
    swayosd # `swayosd-server` / `swayosd-client`
    wlogout
    polkit_gnome
  ];

  #########################################################################
  ## Hyprlock — neon glass locker (blurred screenshot + cyan/green accents)
  #########################################################################
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        no_fade_in = false;
        no_fade_out = false;
        hide_cursor = false;
        grace = 0;
        disable_loading_bar = true;
      };

      background = [
        {
          monitor = "";
          path = "screenshot"; # frosted-glass: blur whatever was on screen
          color = "rgba(10, 10, 18, 1.0)"; # fallback
          blur_passes = 3;
          blur_size = 8;
          brightness = 0.6;
          vibrancy = 0.2;
        }
      ];

      # Glass center panel
      shape = [
        {
          monitor = "";
          size = "26%, 32%";
          color = "rgba(10, 10, 18, 0.75)";
          rounding = 16;
          border_size = 2;
          border_color = "rgb(33ccff)"; # neon cyan
          rotate = 0;
          position = "0%, 0%";
          halign = "center";
          valign = "center";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "21%, 5.5%";
          outline_thickness = 2;
          dots_size = 0.3;
          dots_spacing = 0.3;
          dots_center = true;
          outer_color = "rgb(33ccff)"; # neon cyan
          inner_color = "rgba(16, 18, 28, 0.9)";
          font_color = "rgb(d8f0ff)";
          fade_on_empty = false;
          placeholder_text = ''<span foreground="##66788c">請輸入密碼</span>'';
          hide_input = true;
          check_color = "rgb(00ff99)"; # neon green
          fail_color = "rgb(ff3366)"; # neon magenta-red
          fail_text = "<b>驗證失敗</b>";
          capslock_color = "rgb(ffcc66)"; # neon amber
          position = "0%, -4%";
          halign = "center";
          valign = "center";
          rounding = 12;
          font_size = 16;
        }
      ];

      label = [
        # Phrase of the day — Traditional Chinese
        {
          monitor = "";
          text = ''cmd[update:3600000] sed -n "$(($(date +%j) % $(wc -l < ~/.config/hypr/phrases_zh.txt) + 1))p" ~/.config/hypr/phrases_zh.txt'';
          color = "rgb(d8f0ff)";
          font_size = 30;
          font_family = font;
          position = "0%, -23%";
          halign = "center";
          valign = "center";
        }
        # Time
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +"%H:%M:%S")"'';
          color = "rgb(33ccff)"; # neon cyan clock
          font_size = 48;
          font_family = "${font} Bold";
          position = "0%, 7%";
          halign = "center";
          valign = "center";
        }
        # Date (Chinese)
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +"%Y年%m月%d日") $(case $(date +%u) in 1) echo "星期一";; 2) echo "星期二";; 3) echo "星期三";; 4) echo "星期四";; 5) echo "星期五";; 6) echo "星期六";; 7) echo "星期日";; esac)"'';
          color = "rgb(d8f0ff)";
          font_size = 18;
          font_family = font;
          position = "0%, 2%";
          halign = "center";
          valign = "center";
        }
        # User@host
        {
          monitor = "";
          text = ''cmd[update:0] echo "$USER@$(uname -n)"'';
          color = "rgb(d8f0ff)";
          font_size = 18;
          font_family = font;
          position = "0%, -10%";
          halign = "center";
          valign = "center";
        }
        # System status (top-left)
        {
          monitor = "";
          text = ''cmd[update:1000] echo "  $(uname -n) | $(uname -r)  "'';
          color = "rgb(d8f0ff)";
          font_size = 16;
          font_family = font;
          position = "1%, -3%";
          halign = "left";
          valign = "top";
        }
        # Now playing (top-center)
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(~/.config/scripts/whatsong.sh)"'';
          color = "rgb(d8f0ff)";
          font_size = 16;
          font_family = font;
          position = "0%, -3%";
          halign = "center";
          valign = "top";
        }
        # Battery + memory (top-right)
        {
          monitor = "";
          text = ''cmd[update:30000] echo "  電池: $(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo 'AC')% | 記憶體: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')  "'';
          color = "rgb(d8f0ff)";
          font_size = 16;
          font_family = font;
          position = "-1%, -3%";
          halign = "right";
          valign = "top";
        }
      ];
    };
  };

  #########################################################################
  ## Hypridle — idle daemon (HM systemd user service)
  #########################################################################
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "brightnessctl -s set 10";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 150;
          on-timeout = "brightnessctl -sd rgb:kbd_backlight set 0";
          on-resume = "brightnessctl -rd rgb:kbd_backlight";
        }
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  #########################################################################
  ## Hyprpaper — wallpaper daemon (HM systemd user service)
  #########################################################################
  services.hyprpaper = {
    enable = true;
    settings = {
      # hyprpaper >=0.8 parses `wallpaper` as a *section* (hyprlang special
      # category keyed on `monitor`), not the old flat `monitor,path` string —
      # and it dropped `preload` entirely. The old one-line form is silently
      # ignored, which shows up only as "Monitor eDP-1 has no target" in the
      # log. An empty `monitor` is the wildcard (matches every output).
      wallpaper = [
        {
          monitor = "";
          path = "~/.config/backgrounds/nixos.png";
        }
      ];
    };
  };

  #########################################################################
  ## Udiskie — auto-mount removable media (HM systemd user service)
  ##
  ## Talks to the system udisks2 service enabled in hosts/common.nix and mounts
  ## drives as they are plugged in, under /run/media/$USER/<label>. `tray` puts
  ## an eject/unmount menu in waybar's tray module — it is a StatusNotifierItem,
  ## so it needs waybar running; the unit already Requires/After tray.target,
  ## which HM links because waybar is WantedBy it.
  #########################################################################
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true; # swaync shows the "mounted at …" pop-up
    tray = "auto"; # icon appears only while a removable device is present
  };

  #########################################################################
  ## Wofi — app launcher (config inlined; CSS carried as in-repo files)
  #########################################################################
  programs.wofi = {
    enable = true;
    settings = {
      width = 1200;
      height = 600;
      location = "center";
      show = "drun";
      prompt = "Search...";
      filter_rate = 100;
      allow_markup = true;
      no_actions = true;
      halign = "fill";
      orientation = "vertical";
      content_halign = "fill";
      insensitive = true;
      allow_images = true;
      image_size = 40;
      gtk_dark = true;
    };
    style = builtins.readFile ./files/wofi/style.css;
  };

  #########################################################################
  ## Opaque config blobs carried verbatim (CSS / rasi / icons / assets).
  ## These have no meaningful "attribute set" form — pure-Nix here means the
  ## files live in the flake and are deployed declaratively.
  #########################################################################
  xdg.configFile = {
    # Hyprlock assets + Chinese phrases (referenced by hyprlock.conf above).
    "hypr/assets".source = ./files/hypr/assets;
    "hypr/phrases_zh.txt".source = ./files/hypr/phrases_zh.txt;

    # Rofi (hand-tuned rasi themes + vim/lazyvim cheatsheets).
    "rofi".source = ./files/rofi;

    # Power menu (wlogout layout + style + icons) and its extra wofi style.
    "wlogout".source = ./files/wlogout;
    "wofi/power-menu.css".source = ./files/wofi/power-menu.css;

    # SwayOSD on-screen-display styling.
    "swayosd/style.css".source = ./files/swayosd/style.css;

    # SwayNC notification center styling (overrides its packaged default).
    "swaync/style.css".source = ./files/swaync/style.css;

    # Wallpapers (referenced by services.hyprpaper above).
    "backgrounds".source = ./files/backgrounds;
  };
}
