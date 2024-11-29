{ flakeInputs, config, pkgs, lib, ... }: {

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  age.secrets.homelab-proxy = {
    file = ../secrets/homelab-proxy.age;
    owner = config.services.nginx.user;
  };
  age.secrets.homelab-cert = {
    file = ../secrets/homelab-cert.age;
    owner = config.services.nginx.user;
  };

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;

    recommendedProxySettings = true;

    proxyResolveWhileRunning = true;

    virtualHosts =
      let
        www = host: {
          "www.${host}" = {
            forceSSL = true;
            useACMEHost = host;
            globalRedirect = host;
          };
        };
        basic = host:
          let
            countDots = str:
              builtins.stringLength str -
              builtins.stringLength (builtins.replaceStrings [ "." ] [ "" ] str);
            base.${host} = {
              forceSSL = true;
              enableACME = true;
              root = "/var/www/${host}";
            };
          in
          if countDots host == 1 then base // (www host) else base;
        home-config = {
          forceSSL = true;
          useACMEHost = "necauq.ua";
          extraConfig = "include \"${pkgs.authelia-location}\";";
          locations."/" = {
            # overriden by the homelab-proxy include
            # needs to not be null for recommendedProxySettings to be applied
            proxyPass = "dummy";
            extraConfig = ''
              include "${pkgs.authelia-authrequest}";
              include "${config.age.secrets.homelab-proxy.path}";
              proxy_ssl_trusted_certificate ${config.age.secrets.homelab-cert.path};
              proxy_ssl_verify off;
            '';
          };
        };
      in
      lib.mkMerge [
        (basic "ld47.necauqua.dev")
        (basic "ld49.necauqua.dev")
        (basic "picolauncher.dev")
        (www "necauqua.dev")
        (www "necauq.ua")
        {
          "default" = {
            default = true;
            forceSSL = true; # forceSSL is important so a default https vhost is created too
            useACMEHost = "necauq.ua";
            globalRedirect = "necauq.ua";
          };
          "necauq.ua" = {
            root = "/var/www/necauqua.dev";
            locations."= /healthcheck".extraConfig =
              let
                data = {
                  status = "ok";
                  flakeRev = "${flakeInputs.self.rev or "dirty"}";
                };
              in
              ''
                types {} default_type "application/json; charset=utf-8";
                add_header Access-Control-Allow-Origin *;
                return 200 '${builtins.toJSON data}';
              '';
            locations."= /.well-known/atproto-did".extraConfig = ''
              types {} default_type "text/plain; charset=utf-8";
              add_header Access-Control-Allow-Origin *;
              return 200 'did:plc:5q3nxglkbatgvuvwcu4tnexs';
            '';
          };
          "necauqua.dev" = {
            forceSSL = true;
            enableACME = true;
            globalRedirect = "necauq.ua";
            locations."/.well-known/matrix".extraConfig = ''
              return 404;
            '';
          };
          "home.necauq.ua" = home-config;
          "~^(?<subdomain>.+)\.home\.necauq\.ua" = home-config;
        }
      ];
  };
}
