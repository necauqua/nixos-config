{ config, pkgs, lib, features, ... }:

let
  version = "2.3.2";

  # Komodo serves its web ui from a plain directory of static files, which is
  # built with node and is not part of the nixpkgs komodo package. The official
  # `komodo-ui` image is a scratch image that holds nothing but that directory,
  # so take it from there instead of rebuilding the whole node toolchain.
  ui-image = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/moghtech/komodo-ui";
    imageDigest = "sha256:0310b377463f4eb2be73194f05b4a56a2402ce49695b55b29ffc7353e3630eed";
    hash = "sha256-AldvaQvZZzJuNpRb6r29RS1/V1fN0hWeSpXVXfQycGY=";
    finalImageName = "ghcr.io/moghtech/komodo-ui";
    finalImageTag = version;
  };

  ui = pkgs.runCommand "komodo-ui-${version}"
    { nativeBuildInputs = [ pkgs.jq ]; } ''
    mkdir -p $out
    manifest=$(tar -xOf ${ui-image} manifest.json)
    for layer in $(jq -r '.[0].Layers[]' <<< "$manifest"); do
      tar -xOf ${ui-image} "$layer" | tar -x -C $out
    done
  '';

  # the local agent keeps the stacks it manages here, and Core puts its
  # database dumps next to them
  root = config.services.komodo-periphery.rootDirectory;

  state = "/var/lib/komodo";
in
{
  # Core always comes with an agent for its own host
  imports = [ features.komodo ];

  assertions = [{
    assertion = pkgs.komodo.version == version;
    message = "komodo-core: the ui image is pinned to ${version}, but pkgs.komodo is ${pkgs.komodo.version}";
  }];

  # KOMODO_JWT_SECRET, KOMODO_WEBHOOK_SECRET and KOMODO_DATABASE_PASSWORD
  secrets.komodo.owner = "komodo";
  secrets.komodo-core-key.owner = "komodo";

  users.users.komodo = {
    isSystemUser = true;
    group = "komodo";
    home = state;
  };
  users.groups.komodo = { };

  # the docker provider cannot see a host service, so the route for core
  # comes from the file provider
  services.traefik.dynamicConfigOptions.http = {
    routers.komodo = {
      rule = "Host(`komodo.home.necauq.ua`)";
      service = "komodo";
    };
    services.komodo.loadBalancer.servers = [{ url = "http://127.0.0.1:9120"; }];
  };

  # Komodo only speaks the mongo wire protocol, and neither mongo nor the
  # ferretdb version it accepts are packaged, so the database stays a container
  virtualisation.oci-containers = {
    backend = "docker";
    containers.komodo-mongo = {
      image = "mongo:8";
      cmd = [ "--quiet" "--wiredTigerCacheSizeGB" "0.25" ];
      ports = [ "127.0.0.1:27017:27017" ];
      volumes = [
        "komodo_mongo-data:/data/db"
        "komodo_mongo-config:/data/configdb"
      ];
      # keep Komodo's own "stop all containers" away from its database
      labels."komodo.skip" = "true";
    };
  };

  systemd.services.komodo-core = {
    description = "Komodo Core";
    wantedBy = [ "multi-user.target" ];
    requires = [ "docker-komodo-mongo.service" ];
    after = [ "network-online.target" "docker-komodo-mongo.service" ];
    wants = [ "network-online.target" ];

    # git clones the repositories of builds and syncs, deno runs Actions and
    # km takes the database backups
    path = with pkgs; [ git deno komodo ];

    environment = {
      KOMODO_HOST = "https://komodo.home.necauq.ua";
      # traefik is the only thing that has to reach it
      KOMODO_BIND_IP = "127.0.0.1";
      KOMODO_UI_PATH = "${ui}/ui";

      # mongo is published on the loopback interface only
      KOMODO_DATABASE_ADDRESS = "127.0.0.1:27017";
      KOMODO_DATABASE_USERNAME = "admin";

      # authenticates Core to every Periphery agent, the public half is in
      # komodo.nix
      KOMODO_PRIVATE_KEY = "file:${config.age.secrets.komodo-core-key.path}";
      # default accepted agent key, individual Servers can override it
      KOMODO_PERIPHERY_PUBLIC_KEY = "MCowBQYDK2VuAyEA9RY+f12NkFFQPj9oGPYV+WZRkpf1c3jACgVlx27hrUY=";

      KOMODO_FIRST_SERVER_NAME = "Home";
      KOMODO_LOCAL_AUTH = "true";
      KOMODO_DISABLE_USER_REGISTRATION = "true";
      KOMODO_ENABLE_NEW_USERS = "false";
      KOMODO_DISABLE_CONFIRM_DIALOG = "true";
      KOMODO_JWT_TTL = "1-day";

      KOMODO_REPO_DIRECTORY = "${state}/repo-cache";
      KOMODO_ACTION_DIRECTORY = "${state}/action-cache";
      KOMODO_SYNC_DIRECTORY = "${state}/syncs";
      # where `km database backup` writes, run by the Backup Core Database
      # procedure
      KOMODO_CLI_BACKUPS_FOLDER = "${root}/backups";
    };

    serviceConfig = {
      Type = "simple";
      # systemd-tmpfiles refuses every path under /storage, because the pool
      # root belongs to necauqua while the directories below it belong to
      # root, which it treats as an unsafe path transition. The `+` runs this
      # as root and outside the sandbox below.
      ExecStartPre = "+${pkgs.writeShellScript "komodo-core-backups" ''
        mkdir -p ${root}/backups
        chown komodo:komodo ${root}/backups
        chmod 0750 ${root}/backups
      ''}";
      ExecStart = lib.getExe' pkgs.komodo "core";
      EnvironmentFile = config.age.secrets.komodo.path;
      User = "komodo";
      Group = "komodo";
      Restart = "on-failure";
      RestartSec = "10s";
      StateDirectory = "komodo";
      WorkingDirectory = state;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "${root}/backups" ];
    };
  };
}
