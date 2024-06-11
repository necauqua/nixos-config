{ pkgs, config, ... }:
let
  port = 8008;
  ws-port = 8009;
in
{

  age.secrets.coolify.file = ../../secrets/coolify.age;

  # coolify needs root login
  # this means we need to run
  # ssh-keygen -f /data/coolify/ssh/keys/id.root@host.docker.internal -t ed25519 -N "" -C root@coolify
  # on the server manually cuz I was too lazy to figure out the nix way
  # (I mean along with just running the docker-compose thing instead of re-nixing the entirety of coolify eh)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYpjnM7u9pCk6YfFoeIaQ18KVOctzGZb89eQjoOkzqJ root@coolify"
  ];

  virtualisation.docker.daemon.settings = {
    log-driver = "json-file";
    log-opts = {
      max-size = "10m";
      max-file = "3";
    };
  };

  systemd.services.coolify-prepare-files = {
    description = "Setup files for coolify";
    wantedBy = [ "coolify.service" ];
    script = ''
      #! ${pkgs.bash}/bin/bash
      mkdir -p /data/coolify/{source,ssh,applications,databases,backups,services,proxy,webhooks-during-maintenance,ssh/keys,ssh/mux,proxy/dynamic}

      cp -f "${./docker-compose.yml}" /data/coolify/source/docker-compose.yml
      cp -f "${./docker-compose.prod.yml}" /data/coolify/source/docker-compose.prod.yml
      cp -f "${ config.age.secrets.coolify.path }" /data/coolify/source/.env
      cp -f "${./upgrade.sh}" /data/coolify/source/upgrade.sh

      chown -R 9999:root /data/coolify
      chmod -R 700 /data/coolify
    '';
  };

  systemd.services.coolify = {
    script = ''
      APP_PORT=${toString port} SOKETI_PORT=${toString ws-port} "${pkgs.docker}/bin/docker" compose --env-file /data/coolify/source/.env -f /data/coolify/source/docker-compose.yml -f /data/coolify/source/docker-compose.prod.yml up -d --pull always --remove-orphans --force-recreate
    '';
    after = [ "docker.service" "docker.socket" ];
    wantedBy = [ "multi-user.target" ];
  };

  services.nginx = {
    commonHttpConfig = ''
      map $http_upgrade $coolify_addr {
        websocket "http://127.0.0.1:${toString ws-port}";
        default "http://127.0.0.1:${toString port}";
      }
    '';
    virtualHosts."~^(.+?\\.)?coolify\\.necauq\\.ua" = {
      forceSSL = true;
      useACMEHost = "necauq.ua";
      locations."/" = {
        proxyPass = "$coolify_addr";
        proxyWebsockets = true;
        extraConfig = "proxy_pass_header Authorization;";
      };
    };
  };
}
