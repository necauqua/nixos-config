{
  services.nginx.virtualHosts."necauq.ua" =
    let
      hostname = "necauq.ua";
      fqdn = "matrix.${hostname}";
      baseUrl = "https://${fqdn}";
      clientConfig = {
        "m.homeserver" = {
          base_url = baseUrl;
          server_name = hostname;
        };
        "org.matrix.msc3575.proxy".url = baseUrl;
      };
      serverConfig."m.server" = "${fqdn}:443";
      mkWellKnown = data: ''
        types {} default_type "application/json; charset=utf-8";
        add_header Access-Control-Allow-Origin *;
        return 200 '${builtins.toJSON data}';
      '';
    in
    {
      forceSSL = true;
      enableACME = true;
      locations."= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
      locations."= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
    };
}
