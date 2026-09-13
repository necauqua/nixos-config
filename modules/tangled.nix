{ flake-inputs, config, ... }: {
  imports = [
    flake-inputs.tangled.nixosModules.knot
  ];

  services.tangled.knot = {
    enable = true;
    server = {
      owner = "did:plc:5q3nxglkbatgvuvwcu4tnexs";
      hostname = "knot.necauq.ua";
      listenAddr = "127.0.0.1:5443";
      internalListenAddr = "127.0.0.1:5444";
    };
  };

  services.nginx.virtualHosts."knot.necauq.ua" = {
    useACMEHost = "necauq.ua";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${config.services.tangled.knot.server.listenAddr}";
      proxyWebsockets = true;
    };
  };
}
