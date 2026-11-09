{ flake-inputs, config, lib, ... }:
let
  cfg = config.services.tangled.knot-rs;
in
{
  imports = [
    flake-inputs.tangled.nixosModules.knot-rs
  ];

  # nginx reaches the http side of the knot here, so the number itself does
  # not matter
  ports.tangled-knot = { };

  # KNOT_MASTER_KEY, which unseals the signing keys in sealed-keys. The knot
  # cannot prove that it owns its repositories without it
  secrets.knot = { };

  services.tangled.knot-rs = {
    enable = true;
    environmentFile = config.age.secrets.knot.path;
    settings = {
      server = {
        hostname = "knot.necauq.ua";
        admins = [ "did:plc:5q3nxglkbatgvuvwcu4tnexs" ];
        listen_addr = "127.0.0.1:${toString config.ports.tangled-knot}";
        # tangled.org shows clone urls without a port, and sshd of this
        # machine listens on 5555 (modules/ssh.nix)
        ssh_listen_addr = "[::]:22";
      };
      atproto.plc_directory = "https://plc.directory";
      contact.email = "knot@necauq.ua";
      # the repositories are mirrors of sha1 repositories on home and github
      git.object_format = "sha1";
      lfs.store_path = "${cfg.stateDir}/lfs";
      xrpc = {
        trusted_proxy_header = "x-forwarded-for";
        trusted_proxies = [ "127.0.0.1" ];
      };
    };
  };

  # the knot takes port 22 from the tarpit
  services.endlessh.enable = lib.mkForce false;

  systemd.services.knot-rs = {
    restartTriggers = [ config.secrets.knot.hash ];
    # A knot that starts without its sealed keys makes a new identity and a
    # new host key. The keys come from knot-migrate, which imports them from
    # the database of the go knot, so the knot waits for them.
    unitConfig.ConditionPathExists = cfg.settings.secrets.sealed_key_file;
  };

  services.nginx.virtualHosts."knot.necauq.ua" = {
    useACMEHost = "necauq.ua";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${cfg.settings.server.listen_addr}";
      proxyWebsockets = true;
    };
  };
}
