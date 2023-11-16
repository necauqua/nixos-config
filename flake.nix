{
  description = "Deployment for my server cluster";

  inputs.deploy-rs.url = "github:serokell/deploy-rs";

  outputs = inputs @ { self, nixpkgs, deploy-rs }: {
    nixosConfigurations.offsite = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
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
  };
}
