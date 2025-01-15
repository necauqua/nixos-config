{ config, ... }:
let
  domain = "necauq.ua";
  certDir = config.security.acme.certs.${domain}.directory;
in
{
  services.soju = {
    enable = true;
    hostName = domain;
    tlsCertificate = "${certDir}/full.pem";
    tlsCertificateKey = "${certDir}/key.pem";
    extraConfig = "listen ident://";
  };

  services.nginx.virtualHosts.${domain}.enableACME = true;
  security.acme.certs.${domain}.postRun = "systemctl restart soju.service";

  systemd.services.soju.serviceConfig = {
    AmbientCapabilities = "CAP_NET_BIND_SERVICE"; # allow it to listen on 113
    Group = config.services.nginx.group;
  };

  networking.firewall.allowedTCPPorts = [ 113 6697 ];
}
