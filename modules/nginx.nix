{ flakeInputs, lib, ... }: {
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

  services.nginx.virtualHosts =
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
          globalRedirect = "necauq.ua";
          default = true;
        };
        "necauq.ua" =
          let
            returnJson = data: ''
              types {} default_type "application/json; charset=utf-8";
              add_header Access-Control-Allow-Origin *;
              return 200 '${builtins.toJSON data}';
            '';
          in
          {
            forceSSL = true;
            enableACME = true;
            locations."= /healthcheck".extraConfig = returnJson {
              status = "ok";
              flakeRev = "${flakeInputs.self.rev or "dirty"}";
            };
            root = "/var/www/necauqua.dev";
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

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
