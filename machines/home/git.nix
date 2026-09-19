{ config, pkgs, lib, ... }:

let
  # the ssh endpoint of the git server. The web side of a repository is the
  # radicle client, which radicle.nix serves under this very name
  domain = "git.home.necauq.ua";
  # the bare repositories, this machine holds the source of truth
  root = "/storage/git";
  hooks = "/etc/git/hooks";

  github-user = "necauqua";

  # the radicle home of radicle-node, fixed by the upstream module (radicle.nix)
  rad-home = "/var/lib/radicle";

  # radicle-httpd names a repository by its alias, and it reads the alias list
  # at start only, so a new rid reaches the web gateway through a restart
  # (radicle.nix)
  systemctl = "${config.systemd.package}/bin/systemctl";
  httpd-restart = "${systemctl} try-restart radicle-httpd.service";

  # radicle-node runs confined under its own user, so the radicle half of the
  # mirror runs as that user and the git user reaches it through sudo
  rad-mirror = pkgs.writeShellApplication {
    name = "rad-mirror";
    runtimeInputs = [ pkgs.git pkgs.radicle-node ];
    text = ''
      export RAD_HOME=${rad-home}
      # rad refuses to run if it cannot stat $HOME/.gitconfig
      export HOME=${rad-home}
    '' + builtins.readFile ./rad-mirror.sh;
  };

  knot = "knot.necauq.ua";
  # the knot shares the sshd of offsite, which listens here and leaves a tarpit
  # on port 22 (modules/ssh.nix)
  knot-port = 5555;
  # the tangled account that owns the repository records
  tangled-did = "did:plc:5q3nxglkbatgvuvwcu4tnexs";
  tangled-pds = "https://pds.necauq.ua";

  # a tangled repository carries a did of its own, which is the path the knot
  # serves it under, so the push url comes from the record on the pds and not
  # from the name of the repository
  knot-url = pkgs.writeShellApplication {
    name = "git-knot-url";
    runtimeInputs = with pkgs; [ curl jq ];
    text = ''
      name=$1
      cursor=""

      while :; do
        url="${tangled-pds}/xrpc/com.atproto.repo.listRecords?repo=${tangled-did}&collection=sh.tangled.repo&limit=100"
        if [ -n "$cursor" ]; then
          url="$url&cursor=$cursor"
        fi
        response=$(curl -fsSL --max-time 10 "$url")

        # older records carry the name as the record key, newer ones as a field
        did=$(jq -r --arg name "$name" \
          'first(.records[]
            | select((.value.name // (.uri | split("/") | last)) == $name)
            | .value.repoDid)' <<< "$response")

        if [ -n "$did" ]; then
          # the url carries a port, so it is the ssh:// form and not the short one
          printf 'ssh://git@%s:%d/%s\n' "${knot}" ${toString knot-port} "$did"
          exit 0
        fi

        cursor=$(jq -r '.cursor // empty' <<< "$response")
        if [ -z "$cursor" ]; then
          break
        fi
      done

      printf 'no sh.tangled.repo record named %s on %s\n' "$name" "${tangled-pds}" >&2
      exit 1
    '';
  };

  post-receive = pkgs.writeShellApplication {
    name = "git-post-receive";
    runtimeInputs = [ pkgs.git pkgs.openssh ];
    text = ''
      # a mirror that stalls or asks a question must not hold the push back
      export GIT_SSH_COMMAND="ssh -i ${config.age.secrets.git-mirror.path} \
        -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10"
      SUDO=${config.security.wrapperDir}/sudo
      RAD_MIRROR=${lib.getExe rad-mirror}
      SYSTEMCTL=${systemctl}
    '' + builtins.readFile ./git-post-receive.sh;
  };

  git-ssh = pkgs.writeShellApplication {
    name = "git-ssh";
    runtimeInputs = [ pkgs.git knot-url ];
    text = ''
      GIT_DOMAIN=${domain}
      GIT_ROOT=${root}
      GIT_HOOKS=${hooks}
      GIT_KNOT=${knot}
      GITHUB_USER=${github-user}
      SUDO=${config.security.wrapperDir}/sudo
      RAD_MIRROR=${lib.getExe rad-mirror}
      SYSTEMCTL=${systemctl}
    '' + builtins.readFile ./git-ssh.sh;
  };
in
{
  # pushes to the knot and to github go out under this key, its public half
  # belongs on the tangled account and on the github account
  secrets.git-mirror = {
    owner = "git";
    mode = "0400";
  };

  users.users.git = {
    isSystemUser = true;
    group = "git";
    home = root;
    shell = pkgs.bashInteractive;
    # the same keys that reach the machine itself, restricted to the gateway
    openssh.authorizedKeys.keys = map
      (key: ''command="${lib.getExe git-ssh}",restrict ${key}'')
      config.users.users.necauqua.openssh.authorizedKeys.keys;
  };
  users.groups.git = { };

  # the hooks live outside the store, so a repository keeps working across
  # generations instead of pointing at a path that garbage collection took
  environment.etc."git/hooks/post-receive".source = lib.getExe post-receive;

  # the one bridge between the two users: the git user may run this single
  # program as the radicle user, and nothing else
  security.sudo.extraRules = [
    {
      users = [ "git" ];
      runAs = "radicle";
      commands = [{
        command = lib.getExe rad-mirror;
        options = [ "NOPASSWD" ];
      }];
    }
    # the second bridge: this one command line and no other
    {
      users = [ "git" ];
      runAs = "root";
      commands = [{
        command = httpd-restart;
        options = [ "NOPASSWD" ];
      }];
    }
  ];

  programs.ssh.knownHosts = {
    "github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    # the knot runs on offsite and shares its host key (secrets/secrets.nix);
    # ssh keeps a host that listens off port 22 under this spelling
    ${knot} = {
      hostNames = [ "[${knot}]:${toString knot-port}" ];
      publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIATmTop5IhHPpDQUS5l/HA+LgvLtecby0+97Pu/+PI+P";
    };
  };

  # systemd-tmpfiles refuses every path under /storage, see komodo-core.nix,
  # and this also picks up repositories that were put there by hand
  systemd.services.git-repos = {
    description = "Prepare the git repository root";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.git ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p ${root}
      chown git:git ${root}
      chmod 0755 ${root}

      for repo in ${root}/*; do
        [ -d "$repo/objects" ] || continue
        # -f names the file, so git opens no repository of another user and
        # its ownership check never fires. The chown comes after it, because
        # git writes the file through a lock file of its own
        git config -f "$repo/config" core.hooksPath ${hooks}
        chown -R git:git "$repo"
      done
    '';
  };
}
