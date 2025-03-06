{ config, lib, ... }:
let
  cfg = config.services.nginx;
  secret = name: config.age.secrets.${name}.path;
in
{
  options = with lib; {
    custom.services = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "The name of the service, used for the subdomain";
          };
          port = mkOption {
            type = types.int;
            description = "The port the service is running on, to be proxied from the subdomain";
          };
        };
      });
      description = "List of subdomain-port pairs to be proxied";
      default = [ ];
    };
  };

  config = {
    age.secrets =
      let
        mkSecret = name: {
          "${name}" = {
            file = ../secrets + "/${name}";
            owner = cfg.user;
          };
        };
      in
      lib.mkMerge (map mkSecret [
        "selfsig-key"
        "selfsig-cert"
        "homelab-auth"
      ]);

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
          hostDef = port: {
            onlySSL = true;
            sslCertificate = secret "selfsig-cert";
            sslCertificateKey = secret "selfsig-key";
            basicAuthFile = secret "homelab-auth";
            extraConfig = "ssl_stapling off;";

            locations."/" = {
              proxyWebsockets = true;
              extraConfig = ''
                # specifically don't use proxyPass to avoid recommended proxy headers
                # because of course they are applied AFTER extraConfig
                proxy_pass http://127.0.0.1:${toString port};
                proxy_set_header Host $host;

                set_real_ip_from  necauq.ua;
                real_ip_header    X-Forwarded-For;
                real_ip_recursive on;
              '';
            };
          };
        in
        lib.mkMerge
          (
            [{
              # heimdall (hub) running in docker, todo move to nix
              "home.necauq.ua" = hostDef 9999;
            }] ++ (map (s: { "${s.name}.home.necauq.ua" = hostDef s.port; }) config.custom.services)
          );
    };

    systemd.services.nginx.after = [ "network-online.target" ];
    systemd.services.nginx.wants = [ "network-online.target" ];

    networking.firewall.allowedTCPPorts = [ 443 ];
  };
}
