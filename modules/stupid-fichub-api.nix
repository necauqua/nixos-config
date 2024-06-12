{
  services.nginx.virtualHosts."fichub.necauq.ua" = {
    forceSSL = true;
    useACMEHost = "necauq.ua";
    locations."/".extraConfig = ''
      resolver 8.8.8.8;
      proxy_pass https://fichub.net/api/v0/epub;
      proxy_set_header Host fichub.net;
      add_header Access-Control-Allow-Origin *;
    '';
  };
}
