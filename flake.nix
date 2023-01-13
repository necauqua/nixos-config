{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      modules = [
        ./configuration.nix
        {
          nix.registry = {
            # create a 'nixos' registry entry referencing the nixpkgs input of the system
            # to avoid redownloading new unstable nixpkgs on every search/run
            nixos = {
              from = { id = "nixos"; type = "indirect"; };
              flake = nixpkgs;
            };
            system = {
              from = { id = "system"; type = "indirect"; };
              to = { type = "git"; url = "https://git.sr.ht/~necauqua/nixos-config"; };
              exact = false;
            };
            debug = {
              from = { id = "debug"; type = "indirect"; };
              to = { type = "path"; path = "/home/necauqua/projects/nixos-config"; };
              exact = false;
            };
          };
          # and avoid channels altogether and use that input nixpkgs flake
          nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
        }
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.necauqua = import ./home;
        }
      ];
    in {
      nixosConfigurations = {
        main = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = modules ++ [ ./specific/main.nix ];
        };
        flex = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = modules ++ [ ./specific/flex.nix ];
        };
      };
    };
}
