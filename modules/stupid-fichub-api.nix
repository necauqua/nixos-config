{
  services.nginx.virtualHosts."fichub.necauq.ua" = {
    forceSSL = true;
    useACMEHost = "necauq.ua";
    locations."/" = {
      proxyPass = "https://fichub.net/api/v0/epub";
      extraConfig = ''
        proxy_set_header Host fichub.net;
        add_header Access-Control-Allow-Origin *;
      '';
    };
  };
}
