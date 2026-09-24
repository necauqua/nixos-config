{ config, ... }:
let
  domain = "necauq.ua";
in
{

  secrets.murmur-password = { };

  services.murmur = {
    enable = true;
    openFirewall = true;
    welcometext = "yobana rusnya";
    password = "$MURMUR_PASSWORD";
    environmentFile = config.age.secrets.murmur-password.path;
    bandwidth = 320000;
    registerName = "necauqua";
    # registerUrl = "https://${domain}";
    # registerHostname = domain;
    tls = {
      certPath = "${config.security.acme.certs.${domain}.directory}/full.pem";
      keyPath = "${config.security.acme.certs.${domain}.directory}/key.pem";
    };
  };

  security.acme.certs.${domain}.reloadServices = [ "murmur.service" ];
  services.nginx.virtualHosts.${domain}.enableACME = true;
  users.users.murmur.extraGroups = [ "nginx" ];
}
