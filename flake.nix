{
  description = "Declarative NixOS + Home Manager config — Hyprland desktop (Catppuccin Mocha)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Hyprland flake — keeps the compositor and its xdg portal in sync
    # and tracks upstream more closely than nixpkgs.
    hyprland.url = "github:hyprwm/Hyprland";

    # Zen Browser (no nixpkgs package; community flake).
    # Output used below: packages.<system>.default
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      hyprland,
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

      # One entry per machine. The name MUST match the hosts/<name>/ directory
      # and becomes networking.hostName + the nixosConfigurations attr you
      # build with `--flake .#<name>`.
      hosts = [
        "thinkpad-x1-carbon-g7" # ThinkPad X1 Carbon 7th Gen
        "thinkpad-x1-carbon-g12" # ThinkPad X1 Carbon Gen 12 (21KC, Meteor Lake)
      ];

      # Build one nixosSystem per host, threading the per-user settings + the
      # host's own name down to the system + Home Manager modules.
      mkHost =
        hostname:
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
            ./hosts/${hostname}/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = { inherit inputs username; };
              home-manager.users.${username} = import ./home/home.nix;
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;
    };
}
