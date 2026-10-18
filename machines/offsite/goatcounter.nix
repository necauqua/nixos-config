{ config, ... }: {
  services.goatcounter = {
    enable = true;
    proxy = true;
    # Without this, an upgrade leaves the schema old and goatcounter only warns
    extraArgs = [ "-automigrate" ];
  };
  services.nginx.virtualHosts =
    let
      stats-config = {
        forceSSL = true;
        useACMEHost = "necauq.ua";
        # one log for the domain and its subdomains
        accessLog = "/var/log/nginx/stats.necauq.ua.access.log";
        locations."/".proxyPass = with config.services.goatcounter;
          "http://${address}:${toString port}";
      };
    in
    {
      "stats.necauq.ua" = stats-config;
      "~^(?<subdomain>.+)\.stats\.necauq\.ua" = stats-config;
    };

  security.acme.certs."necauq.ua".extraDomainNames = [ "*.stats.necauq.ua" ];
}
