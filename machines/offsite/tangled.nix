{ flake-inputs, config, ... }: {
  imports = [
    flake-inputs.tangled.nixosModules.knot
  ];

  # nginx reaches the first one and the knot itself the second one, so the
  # numbers themselves do not matter. The ssh side of the knot is not here,
  # it shares the sshd of this machine (modules/ssh.nix)
  ports.tangled-knot = { };
  ports.tangled-knot-internal = { };

  services.tangled.knot = {
    enable = true;
    server = {
      owner = "did:plc:5q3nxglkbatgvuvwcu4tnexs";
      hostname = "knot.necauq.ua";
      listenAddr = "127.0.0.1:${toString config.ports.tangled-knot}";
      internalListenAddr = "127.0.0.1:${toString config.ports.tangled-knot-internal}";
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
