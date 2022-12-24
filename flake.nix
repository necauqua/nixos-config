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
        { # create a 'nixos' registry entry referencing the nixpkgs input of the system
          # to avoid redownloading new unstable nixpkgs on every search/run
          nix.registry.nixos = {
            from.id = "nixos";
            from.type = "indirect";
            flake = nixpkgs;
          };
          # and avoid channels and use the flake
          # nix.nixPath = "nixpkgs=${nixpkgs}";
          # ^ not sure if this is even needed if I only use nix-command
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
