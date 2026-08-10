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

  # kanata config (referenced by the hyprland.start hook in hyprland.lua).
  # Carried as an in-repo file — kanata's .kbd format has no HM module.
  xdg.configFile."kanata/config.kbd".source = ./files/kanata/config.kbd;
}
