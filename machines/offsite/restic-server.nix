{ config, pkgs, ... }:
let
  domain = "backup.necauq.ua";
  # nginx is the only thing that reaches it
  port = config.ports.restic-server;
  dataDir = "/storage/restic";
  repo = "${dataDir}/main";
in
{
  ports.restic-server = { };

  secrets = {
    restic-htpasswd = {
      mode = "400";
      owner = "restic";
      group = "restic";
    };
    restic = {
      mode = "400";
      owner = "restic";
      group = "restic";
    };
  };

  environment.systemPackages = [ pkgs.restic ];

  services.restic.server = {
    enable = true;
    inherit dataDir;
    listenAddress = "127.0.0.1:${toString port}";
    appendOnly = true;
    htpasswd-file = config.age.secrets.restic-htpasswd.path;
    extraFlags = [
      "--max-size"
      "429496729600" # 400 GiB, just in case
    ];
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "necauq.ua";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      # remove body size limit, disable buffering and generous timeouts
      extraConfig = ''
        client_max_body_size 0;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  # an on-server prune job as the http surface is append-only
  systemd.services.restic-prune = {
    description = "Prune the restic repository";
    startAt = "Sun 12:00";
    path = [ pkgs.restic ];
    script = ''
      restic -r ${repo} --retry-lock 2h forget --prune \
        --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --keep-yearly 100
      restic -r ${repo} --retry-lock 2h check --read-data-subset=2%
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "restic";
      Group = "restic";
      CacheDirectory = "restic-prune";
      Environment = "RESTIC_CACHE_DIR=/var/cache/restic-prune";
      EnvironmentFile = config.age.secrets.restic.path;
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.restic-prune.timerConfig.Persistent = true;
}
