{
  description = "NixOS configuration";

  inputs = {
    nixpkgs-stable.url = "nixpkgs/nixos-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote";
  };

  outputs = inputs @ { nixpkgs, nixpkgs-stable, home-manager, ... }:
    let
      system = "x86_64-linux";

      inherit (import ./lib.nix { inherit (nixpkgs) lib; }) load-modules;

      homeProfiles = load-modules ./home/profiles;
      nixosModules = load-modules ./modules;

      specialArgs = {
        pkgs-stable = nixpkgs-stable.legacyPackages.${system};
        flake-inputs = inputs;
        modules = nixosModules;
        profiles = homeProfiles;
      };

      hm-roles = import ./home/roles.nix { profiles = homeProfiles; };

      hm-module-main = {
        imports = hm-roles.all;
        home.stateVersion = "22.11";
      };

      hm-nixos = {
        imports = [ home-manager.nixosModules.home-manager ];
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          users.necauqua = hm-module-main;
          extraSpecialArgs = specialArgs;
        };
      };

      machine = _: machine: nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ machine hm-nixos ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.mapAttrs machine (load-modules ./machines);
      homeModules.main = hm-module-main;
    };
}
