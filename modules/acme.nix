{ config, lib, ... }: {

  age.secrets.cloudflare.file = ../secrets/cloudflare.age;

  security.acme = {
    acceptTerms = true;
    defaults.email = "necauqua@gmail.com";

    certs =
      let
        cloudflare = extras: {
          dnsProvider = "cloudflare";
          webroot = lib.mkForce null; # override all the nginx enableACME lines
          credentialsFile = config.age.secrets.cloudflare.path;
          extraDomainNames = extras;
        };
      in
      {
        "necauq.ua" = cloudflare [ "*.necauq.ua" "*.coolify.necauq.ua" ];
      };
  };
}
