{ config, flake-inputs, ... }: {
  imports = [
    flake-inputs.tangled.nixosModules.knot
  ];

  age.secrets.tangled-knot-secret.file = ../secrets/tangled-knot-secret.age;

  services.tangled-knot = {
    enable = true;
    server = {
      hostname = "knot.necauq.ua";
      secretFile = config.age.secrets.tangled-knot-secret.path;
      listenAddr = "127.0.0.1:5443";
      internalListenAddr = "127.0.0.1:5444";
    };
  };

  services.nginx.virtualHosts."knot.necauq.ua" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${config.services.tangled-knot.server.listenAddr}";
      proxyWebsockets = true;
    };
  };
}
