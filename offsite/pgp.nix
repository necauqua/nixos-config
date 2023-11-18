let
  mkResponse = type: stmt: ''
    types {} default_type "${type}; charset=utf-8";
    add_header Access-Control-Allow-Origin *;
    ${stmt};
  '';
  keys = mkResponse "application/pgp-keys" "alias ${./site/pgp.asc}";
  policy = mkResponse "text/plain" "return 200 ''";
  wkdHash = "gcbtxq6fx9tu5g3iyscwoa7psh37wpd7";
  domain = "necauq.ua";
in
{
  services.nginx.virtualHosts."openpgpkey.${domain}" = {
    forceSSL = true;
    enableACME = true;
    locations = {
      "= /.well-known/openpgpkey/${domain}/hu/${wkdHash}".extraConfig = keys;
      "= /.well-known/openpgpkey/${domain}/policy".extraConfig = policy;
    };
  };
  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    locations = {
      "= /pgp.asc".extraConfig = keys;
      # for some reason this does not work for the gpg binary, it only reads the above "advanced" version with the subdomain
      "= /.well-known/openpgpkey/hu/${wkdHash}".extraConfig = keys;
      "= /.well-known/openpgpkey/policy".extraConfig = policy;
    };
  };
}
