{ config, pkgs, lib, ... }:
let
  domain = "necauq.ua";
  certDir = config.security.acme.certs.${domain}.directory;
in
{
  services.soju = {
    enable = true;
    package = pkgs.soju.overrideAttrs (super: {
      patches = [
        ./0001-identd-make-my-special-ident.patch
      ] ++ (super.patches or [ ]);
    });
    hostName = domain;
    tlsCertificate = "${certDir}/full.pem";
    tlsCertificateKey = "${certDir}/key.pem";
    extraConfig = ''
      listen ident://

      title "necauq.ua bouncer"
      motd ${pkgs.runCommand "soju-motd" {} "echo You have taken yourself too seriously. | ${lib.getExe pkgs.cowsay} > $out"}
    '';
  };

  services.nginx.virtualHosts.${domain}.enableACME = true;
  security.acme.certs.${domain}.postRun = "systemctl restart soju.service";

  systemd.services.soju.serviceConfig = {
    AmbientCapabilities = "CAP_NET_BIND_SERVICE"; # allow it to listen on 113
    Group = config.services.nginx.group; # allow it to read certs
  };

  networking.firewall.allowedTCPPorts = [ 113 6697 ];
}
