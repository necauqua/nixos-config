{
  description = "Deployment for my server cluster";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    twitch-archiver.url = "github:necauqua/twitch-archiver";
    twitch-archiver.inputs.nixpkgs.follows = "nixpkgs";

    catfeeder-bot.url = "sourcehut:~necauqua/catfeeder-bot";
    catfeeder-bot.inputs.nixpkgs.follows = "nixpkgs";

    tangled.url = "git+https://tangled.org/tangled.org/core";
    tangled.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, deploy-rs, agenix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      load-modules = p:
        let
          pred = name: type:
            let
              isNix = type == "regular" && pkgs.lib.hasSuffix ".nix" name;
              isNixDir = type == "directory" && builtins.pathExists (p + "/${name}/default.nix");
            in
            isNix || isNixDir;
          transform = name: _: {
            name = pkgs.lib.removeSuffix ".nix" name;
            value = "${p}/${name}";
          };
        in
        pkgs.lib.mapAttrs' transform (pkgs.lib.filterAttrs pred (builtins.readDir p));
    in
    {
      nixosConfigurations.offsite = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = builtins.attrValues (load-modules ./modules);
        specialArgs = {
          inherit inputs;
          secret = name: "${self}/secrets/${name}.age";
        };
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
