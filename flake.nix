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
      lib = import ./lib.nix { inherit (nixpkgs) lib; };

      specialArgs = {
        pkgs-stable = nixpkgs-stable.legacyPackages.${system};
        flake-inputs = inputs;
      };

      hm-roles = import ./home/roles.nix { inherit (lib) load-modules; };

      hm-module-main = args: {
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
    in
    {
      nixosConfigurations = {
        main = nixpkgs.lib.nixosSystem {
          modules = [
            ./configuration.nix
            ./machines/main.nix
            hm-nixos
          ];
          inherit system specialArgs;
        };
        flex = nixpkgs.lib.nixosSystem {
          modules = [
            ./configuration.nix
            ./machines/flex.nix
            hm-nixos
          ];
          inherit system specialArgs;
        };
      };
      homeModules.main = hm-module-main;
    };
}
