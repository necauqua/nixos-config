{
  description = "Deployment for my server cluster";

  inputs = {
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, deploy-rs, agenix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations.offsite = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./offsite/configuration.nix ];
        specialArgs.flakeInputs = inputs;
      };

      deploy.nodes.offsite = {
        hostname = "necauq.ua";
        profiles.system = {
          sshUser = "root";
          path = deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.offsite;
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = [
          agenix.packages.${system}.default
          deploy-rs.packages.${system}.default
        ];
      };
    };
}
