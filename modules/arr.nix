{ ... }: {
  services =
    let yup = { enable = true; openFirewall = true; };
    in {
      jellyfin = yup;
      prowlarr = yup;
      radarr = yup // { user = "necauqua"; group = "users"; };
      sonarr = yup // { user = "necauqua"; group = "users"; };
      jellyseerr = yup;

      nginx = {
        enable = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;

        virtualHosts.default = {
          default = true;
          globalRedirect = "http://hub.local";
        };
        virtualHosts."hub.local".locations."/".proxyPass = "http://localhost:9999";
        virtualHosts."jellyseerr.local".locations."/".proxyPass = "http://localhost:5055";
        virtualHosts."radarr.local".locations."/".proxyPass = "http://localhost:7878";
        virtualHosts."sonarr.local".locations."/".proxyPass = "http://localhost:8989";
        virtualHosts."prowlarr.local".locations."/".proxyPass = "http://localhost:9696";
        virtualHosts."jellyfin.local".locations."/".proxyPass = "http://localhost:8096";

        # defaultListenAddresses = [ "0.0.0.0" ];
      };
    };
}
