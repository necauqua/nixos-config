{ config, lib, ... }: {

  age.secrets.cloudflare.file = ../secrets/cloudflare.age;

  security.acme = {
    acceptTerms = true;
    defaults.email = "necauqua@gmail.com";

    certs =
      let
        cloudflare = domain: {
          "${domain}" = {
            dnsProvider = "cloudflare";
            webroot = lib.mkForce null; # override all the nginx enableACME lines
            credentialsFile = config.age.secrets.cloudflare.path;
            extraDomainNames = [ "*.${domain}" ];
          };
        };
      in
      lib.mkMerge [
        (cloudflare "necauq.ua")
      ];
  };
}
