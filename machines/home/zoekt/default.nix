{ config, pkgs, lib, ... }:

let
  domain = "code.home.necauq.ua";

  # the bare repositories of the git server, which git/ owns
  git-root = "/storage/git";
  # a search result links to the file in the radicle web client, which opens
  # the repository on the seed under its alias (radicle.nix)
  explorer-url = "https://git.home.necauq.ua/nodes/seed.necauq.ua";

  state = "/var/lib/zoekt";
  index = "${state}/index";
  # the post-receive hook of the git server creates this file, and the path
  # unit below starts an index run whenever it exists (git/git-post-receive.sh)
  pending = "${state}/pending";

  # zoekt links a result to a url that it makes from `zoekt.web-url` in the
  # repository, for a fixed set of forges only. The patch adds the layout of
  # the radicle web client to that set
  zoekt = pkgs.zoekt.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./radicle-urls.patch ];
  });

  # the web interface, which asks zoekt-webserver over its json api
  neogrok = pkgs.callPackage ./neogrok.nix { };

  # a file that is the same on several branches is in the index once, with a
  # 64 bit mask of the branches that hold it, so zoekt takes 64 branches of a
  # repository at most
  max-branches = 64;

  index-repos = pkgs.writeShellApplication {
    name = "zoekt-index-repos";
    runtimeInputs = [ pkgs.git zoekt pkgs.universal-ctags ];
    text = ''
      # a push that arrives during this run creates the file again, and the
      # path unit starts the next run after this one
      rm -f ${pending}

      status=0
      declare -A indexed=()

      for repo in ${git-root}/*; do
        [ -d "$repo/objects" ] || continue
        # a repository is public when it is on radicle, the others stay out of
        # the index
        git config -f "$repo/config" --get rad.id > /dev/null || continue

        name=$(basename "$repo")
        # zoekt reads these from the repository itself and from nowhere else
        git config -f "$repo/config" zoekt.name "$name"
        git config -f "$repo/config" zoekt.web-url "${explorer-url}/$name"
        git config -f "$repo/config" zoekt.web-url-type radicle

        # the default branch comes first, zoekt ranks it above the others
        branches=()
        head=$(git --git-dir="$repo" symbolic-ref --quiet --short HEAD || true)
        if [ -n "$head" ] && git --git-dir="$repo" rev-parse --verify --quiet "refs/heads/$head" > /dev/null; then
          branches+=("$head")
        fi
        while read -r branch; do
          [ "$branch" = "$head" ] || branches+=("$branch")
        done < <(git --git-dir="$repo" for-each-ref --format='%(refname:strip=2)' refs/heads/)

        [ ''${#branches[@]} -gt 0 ] || continue
        if [ ''${#branches[@]} -gt ${toString max-branches} ]; then
          printf '%s: %d branches, only the first %d are indexed\n' \
            "$name" ''${#branches[@]} ${toString max-branches} >&2
          branches=("''${branches[@]:0:${toString max-branches}}")
        fi

        # only a repository whose branches moved is indexed again
        if zoekt-git-index -index ${index} \
          -branches "$(IFS=,; printf '%s' "''${branches[*]}")" "$repo"; then
          indexed[$name]=1
        else
          printf '%s: indexing failed\n' "$name" >&2
          status=1
        fi
      done

      # a repository that is gone or no longer on radicle leaves the index.
      # A shard is <name>_v<version>.<number>.zoekt, and the gateway allows no
      # character in a name that zoekt would escape
      for shard in ${index}/*.zoekt; do
        [ -e "$shard" ] || continue
        name=$(basename "$shard")
        name=''${name%_v*.*.zoekt}
        if [ -z "''${indexed[$name]+x}" ]; then
          # a failed run keeps the shards it could not replace
          [ "$status" -eq 0 ] || continue
          printf 'removing %s\n' "$shard" >&2
          rm -f "$shard" "$shard.meta"
        fi
      done

      exit "$status"
    '';
  };
in
{
  ports.zoekt = { };
  ports.neogrok = { };

  # the index job runs as the git user, which owns the repositories and writes
  # the zoekt settings into them. The index itself is public
  systemd.tmpfiles.rules = [
    "d ${state} 0755 git git -"
    "d ${index} 0755 git git -"
  ];

  systemd.services.zoekt-index = {
    description = "Index the public git repositories for code search";
    after = [ "git-repos.service" ];
    # a run at boot and after each deploy, which costs nothing when no branch
    # moved
    wantedBy = [ "multi-user.target" ];
    # and once a day, for a push that the hook missed
    startAt = "daily";
    unitConfig.RequiresMountsFor = [ git-root state ];
    serviceConfig = {
      Type = "oneshot";
      User = "git";
      Group = "git";
      # zoekt writes the shards with the permissions of the umask, and the
      # web server reads them under a user of its own
      UMask = "0022";
      ExecStart = lib.getExe index-repos;
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  systemd.paths.zoekt-index = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathExists = pending;
  };

  systemd.services.zoekt-webserver = {
    description = "Code search over the public git repositories";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # the web server reads new shards on its own, the index job never has
      # to tell it. neogrok is the interface, so zoekt serves the api only
      ExecStart = lib.escapeShellArgs [
        (lib.getExe' zoekt "zoekt-webserver")
        "-listen"
        "127.0.0.1:${toString config.ports.zoekt}"
        "-index"
        index
        "-rpc"
        "-html=false"
      ];
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      Restart = "on-failure";
    };
  };

  systemd.services.neogrok = {
    description = "Web interface of the code search";
    wantedBy = [ "multi-user.target" ];
    wants = [ "zoekt-webserver.service" ];
    after = [ "zoekt-webserver.service" ];
    environment = {
      ZOEKT_URL = "http://127.0.0.1:${toString config.ports.zoekt}";
      HOST = "127.0.0.1";
      PORT = toString config.ports.neogrok;
      # traefik terminates tls, so the server cannot see the origin itself
      ORIGIN = "https://${domain}";
    };
    serviceConfig = {
      ExecStart = lib.getExe neogrok;
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      Restart = "on-failure";
    };
  };

  # the docker provider cannot see a host service, so the route comes from
  # the file provider, as the route of komodo does
  services.traefik.dynamicConfigOptions.http = {
    routers.code = {
      rule = "Host(`${domain}`)";
      service = "code";
    };
    services.code.loadBalancer.servers = [{
      url = "http://127.0.0.1:${toString config.ports.neogrok}";
    }];
  };
}
