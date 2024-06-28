{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-stable, home-manager, agenix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

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

      global = {
        system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
        imports = [ agenix.nixosModules.age ];
      };

      machine = _: machine: nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [ global machine hm-nixos ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.mapAttrs machine (load-modules ./machines);
      homeModules.main = hm-module-main;
      homeModules.headless = {
        imports = hm-roles.headless;
        home.stateVersion = "22.11";
      };
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          agenix.packages.${system}.default
        ];
      };
    };
}
