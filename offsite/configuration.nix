{ pkgs, flakeInputs, ... }:
{
  imports = [ ./hw.nix ];

  nix = {
    nixPath = [ "nixpkgs=${flakeInputs.nixpkgs}" ];
    registry.nixos = {
      from = { id = "nixos"; type = "indirect"; };
      flake = flakeInputs.nixpkgs;
    };
  };

  boot.tmp.cleanOnBoot = true;

  networking = {
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

  security.acme = {
    acceptTerms = true;
    defaults.email = "necauqua@gmail.com";
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
  };

  services.nginx.virtualHosts."necauq.ua" = let
    hostname = "necauq.ua";
    fqdn = "matrix.${hostname}";
    baseUrl = "https://${fqdn}";
    clientConfig = {
      "m.homeserver" = {
        base_url = baseUrl;
        server_name = hostname;
      };
      "org.matrix.msc3575.proxy".url = baseUrl;
    };
    serverConfig."m.server" = "${fqdn}:443";
    returnJson = data: ''
      types {} default_type "application/json; charset=utf-8";
      add_header Access-Control-Allow-Origin *;
      return 200 '${builtins.toJSON data}';
    '';
  in {
    forceSSL = true;
    enableACME = true;
    locations."= /.well-known/matrix/server".extraConfig = returnJson serverConfig;
    locations."= /.well-known/matrix/client".extraConfig = returnJson clientConfig;
    locations."= /healthcheck".extraConfig = returnJson {
      status = "ok";
      flakeRev = "${flakeInputs.self.rev or "dirty"}";
    };
    globalRedirect = "necauqua.dev";
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  system.stateVersion = "23.05";
}
