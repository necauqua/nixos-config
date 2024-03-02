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
      load-modules = path:
        let
          pred = name: type:
            let
              isNix = type == "regular" && pkgs.lib.hasSuffix ".nix" name;
              isNixDir = type == "directory" && builtins.pathExists (path + "/${name}/default.nix");
            in
            isNix || isNixDir;
          transform = name: _: {
            name = pkgs.lib.removeSuffix ".nix" name;
            value = path + "/${name}";
          };
        in
        pkgs.lib.mapAttrs' transform (pkgs.lib.filterAttrs pred (builtins.readDir path));
      global = {
        system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
      };
    in
    {
      nixosConfigurations.offsite = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ global ] ++ (builtins.attrValues (load-modules ./modules));
        specialArgs.flakeInputs = inputs;
      };

      deploy.nodes.offsite = {
        hostname = "necauq.ua";
        profiles.system = {
          path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.offsite;
          sshUser = "root";
          fastConnection = true;
          sshOpts = [ "-p" "5555" ];
        };
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          agenix.packages.${system}.default
          deploy-rs.packages.${system}.default
        ];
      };
    };
}
