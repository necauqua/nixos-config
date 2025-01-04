{ config, ... }: {
  services.goatcounter = {
    enable = true;
    proxy = true;
  };
  services.nginx.virtualHosts =
    let
      stats-config = {
        forceSSL = true;
        useACMEHost = "necauq.ua";
        locations."/".proxyPass = with config.services.goatcounter;
          "http://${address}:${builtins.toString port}";
      };
    in
    {
      "stats.necauq.ua" = stats-config;
      "~^(?<subdomain>.+)\.stats\.necauq\.ua" = stats-config;
    };

  security.acme.certs."necauq.ua".extraDomainNames = [ "*.stats.necauq.ua" ];
}
