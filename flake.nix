{
  description = "NixOS configuration";

  inputs = {
    # can be updated separately with `nix flake update nixpkgs-future`
    # or even set to latest master with `nix flake lock --override-input nixpkgs-future github:NixOS/nixpkgs/master`
    nixpkgs-future.url = "nixpkgs/nixos-unstable";

    nixpkgs.url = "nixpkgs/nixos-unstable";

    nixpkgs-stable.url = "nixpkgs/nixos-26.05";

    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";

    csshacks.url = "github:MrOtherGuy/firefox-csshacks";
    csshacks.flake = false;

    docker-zfs-plugin.url = "github:ReneHollander/docker-zfs-plugin";
    docker-zfs-plugin.inputs.nixpkgs.follows = "nixpkgs";

    twitch-archiver.url = "github:necauqua/twitch-archiver";
    twitch-archiver.inputs.nixpkgs.follows = "nixpkgs";

    tangled.url = "git+https://tangled.org/tangled.org/core";
    tangled.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ { self, nixpkgs, nixpkgs-stable, nixpkgs-future, agenix, deploy-rs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      inherit (import ./lib.nix { inherit (nixpkgs) lib; }) load-modules;

      profiles = load-modules ./home/profiles;
      features = load-modules ./modules;

      hm-roles = import ./home/roles.nix { inherit profiles; };

      global = {
        system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;
        # `secrets` and `ports` are option definitions every machine may use,
        # so they are global rather than opt-in features
        imports = [ agenix.nixosModules.age features.secrets features.ports ];
      };

      machines = load-modules ./machines;

      machine = modules: nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit features;
          pkgs-stable = nixpkgs-stable.legacyPackages.${system};
          pkgs-future = nixpkgs-future.legacyPackages.${system};
          flake-inputs = inputs;
          hm-profiles = profiles;
        };

        modules = [ global ] ++ modules;
      };

      # the two Oracle Cloud boxes share one machine definition and differ
      # only by host name
      micros = nixpkgs.lib.genAttrs [ "micro1" "micro2" ] (name:
        machine [ machines.micro { networking.hostName = name; } ]);
    in
    {
      nixosConfigurations =
        nixpkgs.lib.mapAttrs (_: m: machine [ m ]) (removeAttrs machines [ "micro" ])
        // micros;

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

      deploy.nodes = nixpkgs.lib.mapAttrs
        (name: { hostname, port ? 22, local ? false }: {
          inherit hostname;
          sshOpts = [ "-p" (toString port) ];
          profiles.system = {
            # on a LAN it's faster to push the whole closure than to let the node substitute
            fastConnection = local;
            path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
            sshUser = "root";
          };
        })
        {
          home = { hostname = "home.lan"; local = true; };
          micro1 = { hostname = "79.76.115.225"; port = 5555; };
          micro2 = { hostname = "130.61.249.154"; port = 5555; };
          offsite = { hostname = "necauq.ua"; port = 5555; };
        };

      checks = builtins.mapAttrs (_: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          agenix.packages.${system}.default
          deploy-rs.packages.${system}.default
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };
}
