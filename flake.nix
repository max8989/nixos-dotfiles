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
      # Make this config your own: change these three values, rename the
      # hosts/<hostname> directory to match, then build. Nothing else in the
      # tree hard-codes the user, home directory, or machine name.
      # ──────────────────────────────────────────────────────────────────
      username = "maxime"; # login name; home dir becomes /home/<username>
      fullName = "Maxime Gagne"; # GECOS / account description
      hostname = "x1carbon"; # must match the hosts/<hostname>/ directory
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        # Thread the per-user settings down to the system + HM modules.
        specialArgs = { inherit inputs username fullName hostname; };
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
    };
}
