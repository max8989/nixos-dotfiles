{
  inputs,
  pkgs,
  ...
}:
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
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;

    # Nothing here: under configType = "lua" each attribute would become an
    # `hl.<name>(...)` call, and the Lua files below already make those calls
    # directly. Keeping both would double every setting.
    settings = { };

    # Written to ~/.config/hypr/keybindings.lua. Home Manager adds the
    # package.path setup and the `require("keybindings")` call to the
    # generated hyprland.lua, so hyprland.lua must not require it itself.
    extraLuaFiles.keybindings = ./files/hypr/keybindings.lua;

    # Appended verbatim to the generated hyprland.lua. The polkit agent has no
    # fixed path on NixOS, so it is substituted in from the Nix store here
    # rather than hard-coded in the Lua.
    extraConfig = builtins.replaceStrings
      [ "@polkitAgent@" ]
      [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ]
      (builtins.readFile ./files/hypr/hyprland.lua);
  };

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
