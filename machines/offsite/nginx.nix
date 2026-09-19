{ lib, ... }: {

  networking.firewall.allowedTCPPorts = [ 80 443 ];

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
          locations."/" = {
            proxyPass = "http://10.100.0.2:8080";
            proxyWebsockets = true;
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
          "streaks.necauq.ua" = {
            forceSSL = true;
            useACMEHost = "necauq.ua";
            root = "/var/www/streaks.necauq.ua";
          };
        }
        {
          "default" = {
            default = true;
            forceSSL = true; # forceSSL is important so a default https vhost is created too
            useACMEHost = "necauq.ua";
            globalRedirect = "necauq.ua";
            redirectCode = 302;
          };
          "noit.ing" = {
            enableACME = true;
            forceSSL = true;
            globalRedirect = "www.twitch.tv/necauqua";
            redirectCode = 302;
            locations."/brine".extraConfig = ''
              return 302 https://twitch.tv/team/brinesquad;
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
          "uq.rs" = {
            forceSSL = true;
            enableACME = true;
            globalRedirect = "necauq.ua";
            redirectCode = 302;
            locations =
              let
                redirect = target: {
                  extraConfig = "return 302 ${target};";
                };
              in
              {
                "= /last-reply" = redirect "https://necauq.ua/limatoukka/last-reply";
                "= /last-bet" = redirect "https://necauq.ua/limatoukka/last-bet";

                "= /help" = redirect "https://necauq.ua/tpn-script-reference/";
                "= /playlist" = redirect "https://music.youtube.com/playlist?list=PLocUClmbybrZVBKmkrEylwSIDq8H6tq4m";
                "= /wands" = redirect "https://dev.onlywands.com/streamer/necauqua";
                "= /box" = redirect "https://github.com/necauqua/noita-utility-box";
                "= /-streak" = redirect "https://github.com/necauqua/negative-streak";

                "~ ^/s/?([a-zA-Z0-9_-]+)$" = redirect "https://necauq.ua/images/screenshots/$1.png";
                "~ ^/i/?([a-zA-Z0-9_-]+)$" = redirect "https://necauq.ua/images/$1.png";

                "/lexer".extraConfig = ''
                  root /var/www/lexer;
                  try_files $uri $uri/ $uri/index.html =404;
                '';
              };
          };
          "kibana.necauq.ua" = {
            useACMEHost = "necauq.ua";
            forceSSL = true;
            locations."/".proxyPass = "http://127.0.0.1:5601";
          };
          "elastic.necauq.ua" = {
            useACMEHost = "necauq.ua";
            forceSSL = true;
            locations."/".proxyPass = "http://127.0.0.1:9200";
          };
          "home.necauq.ua" = home-config;
          "~^(?<subdomain>.+)\.home\.necauq\.ua" = home-config;
        }
      ];
  };

  security.acme.certs."necauq.ua".extraDomainNames = [ "*.home.necauq.ua" ];
}
