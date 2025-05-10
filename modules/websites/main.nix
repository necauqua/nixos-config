{ pkgs, flakeInputs, ... }:
let
  dir = "/var/www/necauq.ua";
  mkResponse = type: stmt: ''
    types {} default_type "${type}; charset=utf-8";
    add_header Access-Control-Allow-Origin *;
    ${stmt};
  '';
in
{
  # todo make at least the deployer user creation into a nixos option (repetition here and in fics atm)
  users.users.main-deployer = {
    isNormalUser = true;
    shell = pkgs.dash;
    home = dir;
    group = "rsync-restricted";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZgaJbL4/wHjKdgt0dtugl3nEEm0jKeRRULHjham7+N main-deployer"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
    ];
  };
  systemd.tmpfiles.rules = [
    "d ${dir} 0755 main-deployer rsync-restricted"
  ];

  services.nginx.virtualHosts."necauq.ua" = {
    root = dir;

    extraConfig = ''
      index index.html;
      error_page 404 /404.html;
    '';

    locations = {
      "= /healthcheck".extraConfig =
        let
          data = {
            status = "ok";
            flakeRev = "${flakeInputs.self.rev or "dirty"}";
          };
        in
        mkResponse "application/json" "return 200 '${builtins.toJSON data}'";

      "= /pgp.asc".extraConfig = mkResponse "application/pgp-keys" "alias ${../../site/pgp.asc}";

      "= /.well-known/atproto-did".extraConfig = mkResponse "text/plain" "return 200 'did:plc:5q3nxglkbatgvuvwcu4tnexs'";

      # meh
      "= /.well-known/nostr.json".extraConfig =
        let
          pkey = "a73d94b5035f4867aa7cf8a1199b017980e9e3bac194e7023134edd2d41d7739";
        in
        mkResponse "application/json"
          "return 200 '${builtins.toJSON {
            names = {
              _ = pkey;
              him = pkey;
              self = pkey;
            };
          }}'";

      # old leftovers, todo do this properly idk
      "/images/".root = "/var/www/necauqua.dev";
      "/videos/".root = "/var/www/necauqua.dev";
      "/twitch/".root = "/var/www/necauqua.dev";
      "= /ft".alias = "/var/www/necauqua.dev/ft";

      "/".tryFiles = "$uri $uri.html $uri/ =404";
    };
  };
}
