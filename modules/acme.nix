{ config, lib, ... }: {

  secrets.cloudflare = { };

  security.acme = {
    acceptTerms = true;
    defaults.email = "necauqua@gmail.com";

    certs = {
      "necauq.ua" = {
        dnsProvider = "cloudflare";
        webroot = lib.mkForce null; # override all the nginx enableACME lines
        credentialsFile = config.age.secrets.cloudflare.path;
        extraDomainNames = [ "*.necauq.ua" ];
      };
    };
  };
}
