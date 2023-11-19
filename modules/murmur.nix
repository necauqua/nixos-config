{ config, ... }:
let
  domain = "necauq.ua";
in
{

  age.secrets.murmur-password.file = ../secrets/murmur-password.age;

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

    sslCert = "${config.security.acme.certs.${domain}.directory}/full.pem";
    sslKey = "${config.security.acme.certs.${domain}.directory}/key.pem";
  };

  security.acme.certs.${domain}.postRun = "systemctl restart murmur.service";
  services.nginx.virtualHosts."${domain}".enableACME = true;
  users.users.murmur.extraGroups = [ "nginx" ];
}
