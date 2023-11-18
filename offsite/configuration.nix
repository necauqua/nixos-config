{ pkgs, flakeInputs, ... }:
{
  imports = [
    flakeInputs.agenix.nixosModules.age
    ./hw.nix
    ./murmur.nix
    ./nginx.nix
    ./matrix.nix
  ];

  nix = {
    nixPath = [ "nixpkgs=${flakeInputs.nixpkgs}" ];
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

  # #KyivNotKiev
  time.timeZone = "Europe/Kiev";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  programs.fish.enable = true;

  users = {
    defaultUserShell = pkgs.fish;
    mutableUsers = false;
    users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
    ];
  };

  environment.systemPackages = [
    pkgs.helix
  ];

  system.stateVersion = "23.11";
}
