{ config, ... }:
let
  cfg = config.services.bluesky-pds.settings;
in
{

  secrets.pds-env = {
    owner = "pds";
    group = "pds";
  };

  services.bluesky-pds = {
    enable = true;
    settings = {
      PDS_HOSTNAME = "pds.necauq.ua";
      PDS_PORT = 3000;
      PDS_HOST = "127.0.0.1";
    };
    environmentFiles = [
      config.age.secrets.pds-env.path
    ];
  };

  services.nginx.virtualHosts.${cfg.PDS_HOSTNAME} = {
    useACMEHost = "necauq.ua";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${cfg.PDS_HOST}:${toString cfg.PDS_PORT}";
      proxyWebsockets = true;
    };
  };
}
