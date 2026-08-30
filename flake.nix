{
  description = "Declarative NixOS + Home Manager config — Hyprland desktop (Catppuccin Mocha) + headless home server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Hyprland flake — keeps the compositor and its xdg portal in sync
    # and tracks upstream more closely than nixpkgs.
    hyprland.url = "github:hyprwm/Hyprland";

    # Declarative disk partitioning. Each host describes its layout in
    # hosts/<hostname>/disko.nix; `nixos-anywhere` (see README "Install") uses
    # it to partition + format at install time, and the module derives the
    # system's fileSystems.* from it afterwards.
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser (no nixpkgs package; community flake).
    # Output used: homeModules.beta, imported by home/zen.nix. That module is
    # built on Home Manager's own mkFirefoxModule, so home-manager MUST follow
    # ours — otherwise it pulls a second, differently-versioned copy.
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      hyprland,
      disko,
      zen-browser,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # ──────────────────────────────────────────────────────────────────
      # Make this config your own: change username/fullName, then add (or
      # rename) an entry in `hosts` below and create a matching
      # hosts/<hostname>/ directory. Nothing else in the tree hard-codes the
      # user, home directory, or machine name.
      # ──────────────────────────────────────────────────────────────────
      username = "maxime"; # login name; home dir becomes /home/<username>
      fullName = "Maxime Gagne"; # GECOS / account description

      # One entry per machine. The attr name MUST match the hosts/<name>/
      # directory and becomes networking.hostName + the nixosConfigurations
      # attr you build with `--flake .#<name>`.
      #
      # `desktop` picks the profile: true → the host's configuration.nix must
      # import hosts/desktop.nix and gets the full graphical Home Manager
      # config (home/home.nix); false → headless, minimal shell-only Home
      # Manager config (home/server.nix).
      hosts = {
        "thinkpad-x1-carbon-g7" = {
          desktop = true;
        }; # ThinkPad X1 Carbon 7th Gen
        "thinkpad-x1-carbon-g12" = {
          desktop = true;
        }; # ThinkPad X1 Carbon Gen 12 (21KC, Meteor Lake)
        "homeserver" = {
          desktop = false;
        }; # H81M-HD2 / i5-4460 / RTX 3070 — headless media server
      };

      # Build one nixosSystem per host, threading the per-user settings + the
      # host's own name down to the system + Home Manager modules.
      mkHost =
        hostname:
        { desktop }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit
              inputs
              username
              fullName
              hostname
              ;
          };
          modules = [
            disko.nixosModules.disko
            ./hosts/${hostname}/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Move (don't clobber) pre-existing unmanaged files instead of
              # aborting the whole activation. Without this, one stray file —
              # e.g. nwg-look rewriting ~/.config/gtk-4.0/settings.ini —
              # silently blocks every HM change in the rebuild.
              home-manager.backupFileExtension = "hm-bak";
              home-manager.extraSpecialArgs = { inherit inputs username; };
              home-manager.users.${username} = import (if desktop then ./home/home.nix else ./home/server.nix);
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;
    };
}
