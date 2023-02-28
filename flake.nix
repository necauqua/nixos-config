{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-22.11";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nixpkgs-stable, home-manager, ... }:
    let
      system = "x86_64-linux";
      specialArgs = {
        pkgs-stable = nixpkgs-stable.legacyPackages.${system};
      };
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
            # sudo nixos-rebuild switch --flake <main / local>
            # well, for the first setup the full git url would be needed ¯\_(ツ)_/¯
            main = {
              from = { id = "main"; type = "indirect"; };
              to = { type = "git"; url = "https://git.sr.ht/~necauqua/nixos-config"; };
              exact = false;
            };
            local = {
              from = { id = "local"; type = "indirect"; };
              to = { type = "path"; path = "/home/necauqua/projects/nixos-config"; };
              exact = false;
            };
          };
          # and avoid channels altogether and use that input nixpkgs flake
          nix.nixPath = [ "nixpkgs=${nixpkgs}" ];
        }
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.necauqua = import ./home;
            extraSpecialArgs = specialArgs;
          };
        }
      ];
    in {
      nixosConfigurations = {
        main = nixpkgs.lib.nixosSystem {
          modules = modules ++ [ ./specific/main.nix ];
          inherit system specialArgs;
        };
        flex = nixpkgs.lib.nixosSystem {
          modules = modules ++ [ ./specific/flex.nix ];
          inherit system specialArgs;
        };
      };
    };
}
