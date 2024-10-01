{ pkgs, flakeInputs, ... }: {

  imports = [
    flakeInputs.agenix.nixosModules.age
  ];

  nix = {
    nixPath = [ "nixpkgs=${flakeInputs.nixpkgs}" ];
    extraOptions = "experimental-features = nix-command flakes repl-flake";
    registry.nixos = {
      from = { id = "nixos"; type = "indirect"; };
      flake = flakeInputs.nixpkgs;
    };
  };

  boot.tmp.cleanOnBoot = true;

  networking = {
    hostName = "offsite";
    domain = "necauq.ua";
    defaultGateway6 = {
      address = "2a00:7a60:0001:0c00::1";
      interface = "enp3s0";
    };
    interfaces.enp3s0.ipv6.addresses = [{
      address = "2a00:7a60:1:d62::1";
      prefixLength = 64;
    }];
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # #KyivNotKiev
  time.timeZone = "Europe/Kiev";

  programs.fish.enable = true;

  users = {
    users.root.shell = pkgs.fish;
    mutableUsers = false;
  };

  environment.systemPackages = [
    pkgs.helix
  ];

  system.stateVersion = "23.11";
}
