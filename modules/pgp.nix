{ lib, ... }:
let
  mkResponse = type: stmt: ''
    types {} default_type "${type}; charset=utf-8";
    add_header Access-Control-Allow-Origin *;
    ${stmt};
  '';
  keys = mkResponse "application/pgp-keys" "alias ${../site/pgp.bin}";
  policy = mkResponse "text/plain" "return 200 ''";

  ids = [
    # him@necauq.ua
    { hashes = [ "gcbtxq6fx9tu5g3iyscwoa7psh37wpd7" ]; domain = "necauq.ua"; dns = true; }
    # self@necauqua.dev
    { hashes = [ "eyhyzoqumnuxo315g6773ddh3tsdtkdb" ]; domain = "necauqua.dev"; }
  ];

  mapMerge = f: xs: lib.attrsets.mergeAttrsList (builtins.map f xs);

  wkdKey = infix: hash: {
    "= /.well-known/openpgpkey/${infix}hu/${hash}".extraConfig = keys;
  };
  wkdLocations = infix: hashes: {
    "= /.well-known/openpgpkey/${infix}policy".extraConfig = policy;
  } // mapMerge (wkdKey infix) hashes;

  defineWKD = { hashes, domain, dns ? false }: {
    "openpgpkey.${domain}" = {
      forceSSL = true;
      enableACME = !dns;
      useACMEHost = if dns then domain else null;
      locations = wkdLocations "${domain}/" hashes;
    };
    ${domain} = {
      forceSSL = true;
      enableACME = true;
      locations = wkdLocations "" hashes // {
        "= /pgp.asc".extraConfig = keys;
      };
    };
  };
in
{
  services.nginx.virtualHosts = mapMerge defineWKD ids;
}
