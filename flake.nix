{
  description = "Maxime's NixOS + Home Manager config — Hyprland desktop (Catppuccin Mocha), fully declarative";

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
    in
    {
      nixosConfigurations.x1carbon = nixpkgs.lib.nixosSystem {
        inherit system;
        # Pass flake inputs down to modules (Hyprland / zen-browser packages).
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/x1carbon/configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.maxime = import ./home/maxime/home.nix;
          }
        ];
      };
    };
}
