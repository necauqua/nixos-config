{ flakeInputs, lib, ... }: {

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedBrotliSettings = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;

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
          };
          "necauqua.dev" = {
            forceSSL = true;
            enableACME = true;
            globalRedirect = "necauq.ua";
            locations."/.well-known/matrix".extraConfig = ''
              return 404;
            '';
          };
          # "uq.rs" = {
          #   forceSSL = true;
          #   enableACME = true;
          #   globalRedirect = "necauqua.dev";
          # };
        }
      ];
  };
}
