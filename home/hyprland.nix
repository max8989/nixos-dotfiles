{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  hyprlandPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

  # Ctrl+Space: us -> ca -> pinyin -> us. Hyprland owns the xkb layouts and
  # fcitx5 owns Pinyin, so one script steps both. Pinyin types over the us
  # layout, which is why leaving it returns to layout 0.
  cycleInput = pkgs.writeShellApplication {
    name = "cycle-input";
    runtimeInputs = [
      hyprlandPackage
      pkgs.fcitx5
      pkgs.jq
    ];
    text = ''
      if [[ "$(fcitx5-remote -n)" == pinyin ]]; then
        fcitx5-remote -s keyboard-us
        hyprctl switchxkblayout all 0
        exit 0
      fi
      keymap=$(hyprctl -j devices | jq -r '[.keyboards[] | select(.main)][0].active_keymap // ""')
      if [[ "$keymap" == *Canadian* || "$keymap" == *French* ]]; then
        hyprctl switchxkblayout all 0
        fcitx5-remote -s pinyin
      else
        hyprctl switchxkblayout all 1
      fi
    '';
  };
in
{
  wayland.windowManager.hyprland = {
    enable = true;

    # Lua config backend (Home Manager's default from stateVersion 26.05).
    # It writes ~/.config/hypr/hyprland.lua; `hyprlang` would write
    # hyprland.conf instead. The config itself lives in the two Lua files
    # under files/hypr/ rather than in `settings`, because it uses loops and
    # locals (per-key bind tables, workspace 1..10) that an attribute set
    # cannot express — the repo's tier-2 rule for opaque blobs.
    configType = "lua";

    # Same Hyprland package the system enables (from the flake input).
    package = hyprlandPackage;

    # Nothing here: under configType = "lua" each attribute would become an
    # `hl.<name>(...)` call, and the Lua files below already make those calls
    # directly. Keeping both would double every setting.
    settings = { };

    # Written to ~/.config/hypr/keybindings.lua. Home Manager adds the
    # package.path setup and the `require("keybindings")` call to the
    # generated hyprland.lua, so hyprland.lua must not require it itself.
    extraLuaFiles.keybindings = ./files/hypr/keybindings.lua;

    extraConfig = builtins.readFile ./files/hypr/hyprland.lua;

  };

  xdg.configFile."hypr/theme.lua".text = "return " + lib.generators.toLua { } (import ./palette.nix);

  xdg.configFile."hypr/shell_commands.lua".text =
    let
      ipc =
        args:
        lib.escapeShellArgs (
          [
            (lib.getExe pkgs.quickshell)
            "ipc"
            "--config"
            "desktop"
            "call"
          ]
          ++ args
        );
      menu =
        name:
        ipc [
          "menus"
          "toggle"
          name
        ];
      commands = {
        controls = menu "controls";
        apps = menu "apps";
        files = menu "files";
        clipboard = menu "clipboard";
        vim = menu "vim";
        lazyvim = menu "lazyvim";
        power = menu "power";
        audio = menu "audio";
        wifi = menu "wifi";
        display = menu "display";
        battery = menu "battery";
        cycleInput = lib.getExe cycleInput;
        volumeUp = ipc [
          "audio"
          "volume"
          "5"
        ];
        volumeDown = ipc [
          "audio"
          "volume"
          "-5"
        ];
        microphoneUp = ipc [
          "audio"
          "microphone"
          "5"
        ];
        microphoneDown = ipc [
          "audio"
          "microphone"
          "-5"
        ];
        mute = ipc [
          "audio"
          "mute"
        ];
        muteMicrophone = ipc [
          "audio"
          "muteMicrophone"
        ];
        brightnessUp = ipc [
          "display"
          "brightness"
          "5"
        ];
        brightnessDown = ipc [
          "display"
          "brightness"
          "-5"
        ];
        mediaNext = ipc [
          "media"
          "control"
          "next"
        ];
        mediaPrevious = ipc [
          "media"
          "control"
          "previous"
        ];
        mediaToggle = ipc [
          "media"
          "control"
          "toggle"
        ];
      };
    in
    "return " + lib.generators.toLua { } commands;

  ##########################################################################
  ## kanata (caps-lock vim nav + j/k Escape chord).
  ##
  ## A systemd user service on default.target, NOT a Hyprland exec — kanata
  ## works at the evdev level and needs no Wayland session, so tying it to the
  ## compositor only makes it fragile: a Hyprland config error means no
  ## remapping at all, and a compositor restart drops it. Restart=on-failure
  ## also gets it back after a crash, which an exec-once never would.
  ## This matches the Arch unit's own rationale.
  ##
  ## /dev/uinput access comes from hardware.uinput.enable + the uinput/input
  ## groups in hosts/common.nix.
  ##########################################################################
  systemd.user.services.kanata = {
    Unit = {
      Description = "Kanata keyboard remapper";
      Documentation = "https://github.com/jtroo/kanata";
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kanata}/bin/kanata --cfg %h/.config/kanata/config.kbd";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };

  # kanata config (read by the service above). Carried as an in-repo file —
  # kanata's .kbd format has no HM module.
  xdg.configFile."kanata/config.kbd".source = ./files/kanata/config.kbd;
}
