{ ... }: {

  # every certificate here uses the cloudflare dns-01 challenge
  secrets.cloudflare = { };

  security.acme = {
    acceptTerms = true;
    defaults.email = "necauqua@gmail.com";
  };
}
