{ config, ... }:
let
  subdomain = "ntfy";
in
{
  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://${subdomain}.necauq.ua";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-default-access = "deny-all";
    };
  };
  services.nginx.virtualHosts."${subdomain}.necauq.ua" = {
    useACMEHost = "necauq.ua";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${config.services.ntfy-sh.settings.listen-http}";
      proxyWebsockets = true;
    };
  };
}
