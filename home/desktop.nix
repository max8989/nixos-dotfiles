{
  config,
  lib,
  pkgs,
  ...
}:
let
  palette = import ./palette.nix;
  jadeWallpaper = pkgs.runCommand "jade-wallpaper" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
    mkdir -p "$out"
    rsvg-convert ${./files/backgrounds/jade-landscape.svg} -o "$out/jade-landscape.png"
  '';
in
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${lib.getExe pkgs.quickshell} ipc --config desktop call session lock";
        inhibit_sleep = 3;
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
  ## Hyprsunset — blue-light filter / night light (HM systemd user service)
  ##
  ## The daemon itself is a no-op at rest: the single profile below is
  ## `identity = true`, so nothing is tinted until something asks it to be.
  ## Control is manual, from Quickshell, which talks to
  ## this daemon over hyprctl IPC (`hyprctl hyprsunset temperature 4000` /
  ## `hyprctl hyprsunset identity`) — see quickshell/services/Display.qml.
  ## The daemon must be running for those IPC calls to land at all.
  ##
  ## To make it warm up on a schedule instead, add a second profile — profiles
  ## activate at their `time` and reset everything the previous one set, which
  ## also means an evening profile would stomp a manual toggle at that hour:
  ##   { time = "21:00"; temperature = 4000; }
  ##
  ## Do NOT use the module's `transitions` option — it is deprecated upstream
  ## in favour of `settings`.
  #########################################################################
  services.hyprsunset = {
    enable = true;
    settings = {
      max-gamma = 100;
      profile = [
        {
          time = "00:00";
          identity = true;
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
          path = "${jadeWallpaper}/jade-landscape.png";
        }
      ];
    };
  };

  #########################################################################
  ## Hyprshell — Alt-Tab window switcher (HM systemd user service)
  ##
  ## Successor to hyprswitch. It registers its own Alt+Tab shortcut through
  ## Hyprland's global-shortcuts protocol, so there is deliberately no bind in
  ## home/files/hypr/keybindings.lua — configuring `switch` here *is* the
  ## keybind. Hold ALT and tap TAB (SHIFT+TAB / grave to go backwards), release
  ## ALT to focus the selection.
  ##
  ## `version` is mandatory and must match the schema hyprshell ships with (4
  ## as of 4.10.x). Omitting it, or leaving it behind, makes hyprshell try to
  ## *rewrite* the config on startup — and Home Manager makes
  ## ~/.config/hyprshell/config.json a read-only Nix store symlink, so that
  ## migration can never succeed. Bump it when the package moves to a newer
  ## schema; `hyprshell config check` reports the mismatch.
  ##
  ## Fields are validated strictly: an unknown key makes hyprshell refuse the
  ## whole config. `windows` accepts scale / items_per_row / overview / switch /
  ## switch_2; `switch` accepts modifier / key / filter_by / switch_workspaces /
  ## exclude_workspaces / kill_key. There is no `enable` key — a section is on
  ## because it is present, so leaving `overview` out keeps the SUPER overview
  ## + launcher off and only ships the Alt-Tab switcher.
  #########################################################################
  services.hyprshell = {
    enable = true;
    style = ''
      :root {
        --border-color: ${palette.border};
        --border-color-active: ${palette.accent};
        --bg-color: ${palette.base};
        --bg-color-hover: ${palette.raised};
        --bg-window-color: ${palette.background};
        --text-color: ${palette.text};
        --border-radius: 14px;
        --border-size: 2px;
        --border-style: solid;
      }
      .window { font-family: Figtree; }
    '';
    settings = {
      version = 4;
      windows = {
        switch = {
          modifier = "alt";
          key = "tab";
        };
      };
    };
  };

  #########################################################################
  ## Udiskie — auto-mount removable media (HM systemd user service)
  ##
  ## Talks to the system udisks2 service enabled in hosts/common.nix and mounts
  ## drives as they are plugged in, under /run/media/$USER/<label>. `tray` puts
  ## an eject/unmount menu in Quickshell’s tray — it is a StatusNotifierItem,
  ## so it needs Quickshell running; the unit already Requires/After tray.target,
  ## which HM links because Quickshell is WantedBy it.
  #########################################################################
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true; # Quickshell shows the "mounted at …" pop-up
    tray = "auto"; # icon appears only while a removable device is present
  };

  #########################################################################
  ## LocalSend — always reachable on the LAN (port 53317 opened in common.nix)
  ##
  ## `--hidden` starts it straight into Quickshell's tray instead of opening
  ## the window; LocalSend's own "start on login" toggle writes an XDG
  ## autostart file, which Hyprland doesn't process. Same tray.target ordering
  ## as udiskie so the StatusNotifierItem has a host to register with.
  #########################################################################
  systemd.user.services.localsend = {
    Unit = {
      Description = "LocalSend file sharing";
      Requires = [ "tray.target" ];
      After = [
        "graphical-session.target"
        "tray.target"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe' pkgs.localsend "localsend_app"} --hidden";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  #########################################################################
  ## Default applications — Dolphin is the main file manager.
  ##
  ## inode/directory is the only type Dolphin's desktop file declares, and it
  ## is what "open containing folder" in other apps resolves through.
  ## Enabling this makes ~/.config/mimeapps.list a read-only store symlink, so
  ## any "set as default" button in a GUI app will silently fail to persist —
  ## add the association here instead.
  #########################################################################
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Zen handles web links and saved web pages.
      "x-scheme-handler/http" = [ "zen-beta.desktop" ];
      "x-scheme-handler/https" = [ "zen-beta.desktop" ];
      "text/html" = [ "zen-beta.desktop" ];
      "application/xhtml+xml" = [ "zen-beta.desktop" ];

      "inode/directory" = [ "org.kde.dolphin.desktop" ];

      # Okular ships one desktop entry per format; org.kde.okular.desktop
      # itself only claims application/vnd.kde.okular-archive, so the PDF
      # association has to name okularApplication_pdf.desktop. It is
      # NoDisplay=true (hidden from menus) but valid as a default handler.
      "application/pdf" = [ "okularApplication_pdf.desktop" ];

      "text/plain" = [ "org.kde.kate.desktop" ];

      # Images → Gwenview. imv and zathura's mupdf backend also claim several
      # of these, so the association has to be explicit or the winner is
      # whichever .desktop the mime cache happens to rank first.
      "image/jpeg" = [ "org.kde.gwenview.desktop" ];
      "image/png" = [ "org.kde.gwenview.desktop" ];
      "image/gif" = [ "org.kde.gwenview.desktop" ];
      "image/webp" = [ "org.kde.gwenview.desktop" ];
      "image/bmp" = [ "org.kde.gwenview.desktop" ];
      "image/tiff" = [ "org.kde.gwenview.desktop" ];
      "image/avif" = [ "org.kde.gwenview.desktop" ];
      "image/heif" = [ "org.kde.gwenview.desktop" ];
      "image/svg+xml" = [ "org.kde.gwenview.desktop" ];

      # Archives → Ark. Only the formats actually reachable day to day; Ark's
      # own desktop entry claims a much longer list.
      "application/zip" = [ "org.kde.ark.desktop" ];
      "application/x-tar" = [ "org.kde.ark.desktop" ];
      "application/x-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-xz-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-bzip2-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/x-zstd-compressed-tar" = [ "org.kde.ark.desktop" ];
      "application/gzip" = [ "org.kde.ark.desktop" ];
      "application/x-xz" = [ "org.kde.ark.desktop" ];
      "application/zstd" = [ "org.kde.ark.desktop" ];
      "application/x-7z-compressed" = [ "org.kde.ark.desktop" ];
      "application/vnd.rar" = [ "org.kde.ark.desktop" ];
    };
  };

  #########################################################################
  ## Opaque config blobs carried verbatim (CSS / rasi / icons / assets).
  ## These have no meaningful "attribute set" form — pure-Nix here means the
  ## files live in the flake and are deployed declaratively.
  #########################################################################
  xdg.configFile = {
    # Wallpapers (referenced by services.hyprpaper above).
    "backgrounds".source = ./files/backgrounds;
  };
}
