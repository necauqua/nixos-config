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

  outputs = inputs @ { self, nixpkgs, nixpkgs-stable, agenix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      inherit (import ./lib.nix { inherit (nixpkgs) lib; }) load-modules;

      profiles = load-modules ./home/profiles;
      features = load-modules ./modules;

      hm-roles = import ./home/roles.nix { inherit profiles; };

      global = {
        system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
        imports = [ agenix.nixosModules.age ];
      };

      machine = _: machine: nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit features;
          pkgs-stable = nixpkgs-stable.legacyPackages.${system};
          flake-inputs = inputs;
          hm-profiles = profiles;
        };

        modules = [ global machine ];
      };
    in
    {
      nixosConfigurations = nixpkgs.lib.mapAttrs machine (load-modules ./machines);
      homeModules = {
        main = {
          imports = hm-roles.all;
          home.stateVersion = "22.11";
        };
        headless = {
          imports = hm-roles.headless;
          home.stateVersion = "22.11";
        };
      };
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          agenix.packages.${system}.default
          (pkgs.writeShellScriptBin "deploy" ''
            flake=$1
            if [[ -z "$flake" ]]; then
              flake=local
            fi
            ulimit -n 65535 # well this is a thing now
            sudo nixos-rebuild switch --flake $flake
          '')
        ];
      };
    };
}
