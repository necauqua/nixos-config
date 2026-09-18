{ config, features, ... }:

let
  domain = "home.necauq.ua";
  cert = config.security.acme.certs.${domain}.directory;
in
{
  imports = [ features.acme ];

  security.acme.certs.${domain} = {
    dnsProvider = "cloudflare";
    dnsResolver = "1.1.1.1:53";
    environmentFile = config.age.secrets.cloudflare.path;
    extraDomainNames = [ "*.${domain}" ];
    # traefik reads the certificate straight from /var/lib/acme and has to be
    # told about a renewal, it does not watch the files itself
    group = "traefik";
    reloadServices = [ "traefik.service" ];
  };

  services.traefik = {
    enable = true;
    # the docker provider needs the socket
    group = "docker";

    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
          };
        };
        websecure = {
          address = ":443";
          http.tls = { };
          # immich moves big files around
          transport.respondingTimeouts = {
            readTimeout = "600s";
            writeTimeout = "600s";
            idleTimeout = "600s";
          };
        };
        # not in the firewall, but wg0 is a trusted interface, so this is
        # reachable through wireguard only
        remote = {
          address = ":8080";
          # keep x-forwarded-proto, otherwise authelia sees plain http
          forwardedHeaders.trustedIPs = [ "10.100.0.1/32" ];
        };
      };

      # containers opt in with `traefik.enable=true` and pick their host name
      # with `traefik.subdomain`, the container name is the fallback
      providers.docker = {
        exposedByDefault = false;
        network = "proxy";
        defaultRule = ''Host(`{{ or (index .Labels "traefik.subdomain") .Name }}.${domain}`)'';
      };
    };

    # the wildcard certificate serves every router on the websecure entrypoint
    dynamicConfigOptions.tls.stores.default.defaultCertificate = {
      certFile = "${cert}/fullchain.pem";
      keyFile = "${cert}/key.pem";
    };
  };

  # the network the proxied containers attach to, it used to come from the
  # komodo compose file
  systemd.services.docker-network-proxy = {
    description = "Create the proxy docker network";
    wantedBy = [ "multi-user.target" ];
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    before = [ "traefik.service" ];
    path = [ config.virtualisation.docker.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker network inspect proxy > /dev/null 2>&1 || docker network create proxy
    '';
  };

  systemd.services.traefik = {
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
