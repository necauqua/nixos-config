{ config, pkgs, lib, ... }:

let
  # the seed itself: the node that peers dial and the http gateway that every
  # radicle web client reads. One name carries both, and it is a name of the
  # public domain because offsite is the machine that answers it: the p2p port
  # over a stream proxy and the http side over wireguard
  seed-domain = "seed.necauq.ua";
  # the web client, which is a static bundle and nothing else
  web-domain = "git.home.necauq.ua";

  # nginx serves the bundle here, traefik is the only thing that reaches it
  web-port = config.ports.radicle-explorer;
  # radicle-httpd, which traefik reaches straight away: the seed has no path
  # to split, so no web server sits in front of it
  httpd-port = config.ports.radicle-httpd;
  # the native radicle protocol. The machine is behind NAT, so offsite listens
  # on this port in public and forwards it here over wireguard
  node-port = 8776;
  # the state directory of radicle-node, which doubles as its RAD_HOME. The
  # upstream module fixes both, rad-mirror in git/ expects the same path
  rad-home = "/var/lib/radicle";

  # the bare repositories of the git server, which git/ owns. Each one that
  # is on radicle carries its rid in `rad.id`
  git-root = "/storage/git";

  # the alias list of radicle-httpd, one `<name> <rid>` line per repository.
  # It is a file and not a command line because the gateway runs confined and
  # cannot read the git root itself
  alias-file = "/run/radicle-httpd/aliases";

  # the node key of this machine. It is a delegate of every repository that
  # the git server mirrors, next to the key of main, so both can write the
  # canonical branch
  public-key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSmQ7+6+f2Sr1o14GTEvRs/TLB5xtjJwSNjtd7e4X0y";

  # The public seeds of the main network, which is how this node reaches every
  # other one: radicle-node dials them on start and learns the rest of the
  # network by gossip from there.
  #
  # They have to be named. radicle-node falls back to its built-in bootstrap
  # list only while `node.connect` is empty *and* its address book is empty,
  # and externalAddresses below puts this machine's own address into the book
  # on the very first start, so that fallback never fires and the node sits
  # alone with no one to dial.
  public-seeds = [
    "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@iris.radicle.network:${toString node-port}"
    "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosa.radicle.network:${toString node-port}"
  ];

  # the web client is a static bundle with its settings baked in, and it opens
  # the seed next to it. radicle-httpd answers every origin, so the bundle
  # reads the seed from its own name, and a foreign client can read this seed
  # under the very same name
  explorer = (pkgs.radicle-explorer.withConfig {
    preferredSeeds = [{
      hostname = seed-domain;
      port = 443;
      scheme = "https";
    }];
  }).overrideAttrs (old: {
    # every repository here is also on github and on tangled, so the header of
    # a repository carries a link to each of them
    patches = (old.patches or [ ]) ++ [ ./radicle-explorer-mirror-links.patch ];
  });

  # Writes the alias list. This runs unconfined, because the git root belongs
  # to the git user and is not part of the radicle world.
  alias-list = pkgs.writeShellApplication {
    name = "radicle-httpd-aliases";
    runtimeInputs = [ pkgs.git ];
    text = ''
      install -d -m 0755 "$(dirname ${alias-file})"
      : > ${alias-file}.new

      for repo in ${git-root}/*; do
        [ -d "$repo/objects" ] || continue
        rid=$(git config -f "$repo/config" --get rad.id) || continue
        printf '%s %s\n' "$(basename "$repo")" "$rid" >> ${alias-file}.new
      done

      chmod 0644 ${alias-file}.new
      mv ${alias-file}.new ${alias-file}
    '';
  };

  # the aliases that the configuration names, for a repository of the network
  # that this machine does not mirror. The wrapper below replaces the command
  # line of the upstream module, so it carries them itself
  static-aliases = lib.flatten (lib.mapAttrsToList
    (name: rid: [ "--alias" name rid ])
    config.services.radicle.httpd.aliases);

  # radicle-httpd takes an alias only on its command line, so the list becomes
  # arguments here, at every start of the service
  httpd-wrapper = pkgs.writeShellApplication {
    name = "radicle-httpd-wrapper";
    text = ''
      args=()
      while read -r name rid; do
        args+=(--alias "$name" "$rid")
      done < ${alias-file}

      exec ${lib.getExe' config.services.radicle.httpd.package "radicle-httpd"} \
        --listen=127.0.0.1:${toString httpd-port} \
        ${lib.escapeShellArgs static-aliases} ''${args[@]+"''${args[@]}"}
    '';
  };
in
{
  # radicle-node reads the key as a systemd credential. rad-mirror runs outside
  # that service and reads the very same file, through the symlink below
  secrets.radicle-key = {
    owner = "radicle";
    mode = "0400";
  };

  # both are behind traefik, so the numbers themselves do not matter
  ports.radicle-httpd = { };
  ports.radicle-explorer = { };

  services.radicle = {
    enable = true;
    privateKey = config.age.secrets.radicle-key.path;
    publicKey = public-key;

    # wg0 is a trusted interface, so the forward from offsite arrives without
    # a firewall rule of its own
    node.listenPort = node-port;

    settings = {
      preferredSeeds = public-seeds;

      web = {
        avatarUrl = "https://necauq.ua/avatar.jpg";
        description = "Self-hosting my git repos with radicle because of it's epic UI";
      };

      node = {
        alias = "necauqua/home";
        # what peers are told to dial, which is the relay and not this machine
        externalAddresses = [ "${seed-domain}:${toString node-port}" ];
        # a repository is replicated only once `rad seed` names it, so the disk
        # holds what this machine publishes and nothing the network offers it
        seedingPolicy.default = "block";
      };
    };

    httpd = {
      enable = true;
      listenPort = httpd-port;

      # a repository of the network that this machine does not hold, browsable
      # under a name of its own. The repositories of the git server get their
      # aliases from the unit below instead
      aliases = {
        heartwood = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
      };
    };
  };

  # a repository is published under its own name and not under its rid, which
  # makes `git clone https://${seed-domain}/<name>` work. The list is built at
  # every start of the gateway, so a repository that the git server puts on
  # radicle needs a restart of radicle-httpd to show up, which the gateway in
  # git/ asks for
  systemd.services.radicle-httpd-aliases = {
    description = "Collect the repository aliases of radicle-httpd";
    after = [ "git-repos.service" ];
    unitConfig.RequiresMountsFor = git-root;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe alias-list;
    };
  };

  systemd.services.radicle-httpd = {
    # the unit above holds no state after it exits, so a restart of the
    # gateway runs it again and the list is never stale
    requires = [ "radicle-httpd-aliases.service" ];
    after = [ "radicle-httpd-aliases.service" ];
    serviceConfig = {
      ExecStart = lib.mkForce (lib.getExe httpd-wrapper);
      BindReadOnlyPaths = [ alias-file ];
    };
  };

  # the node and the gateway run confined, so their radicle home exists inside
  # their own mount namespace only. rad-mirror needs the same profile on the
  # host: the configuration and the public key as plain files, and the private
  # key as a symlink, which leaves the plain text in /run and off the disk
  systemd.services.radicle-profile = {
    description = "Lay out the radicle profile for rad-mirror";
    wantedBy = [ "multi-user.target" ];
    before = [ "radicle-node.service" "radicle-httpd.service" ];
    requiredBy = [ "radicle-node.service" "radicle-httpd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -o radicle -g radicle -m 0750 ${rad-home} ${rad-home}/keys
      install -o radicle -g radicle -m 0644 \
        ${config.services.radicle.configFile} ${rad-home}/config.json
      install -o radicle -g radicle -m 0644 \
        ${pkgs.writeText "radicle.pub" public-key} ${rad-home}/keys/radicle.pub
      ln -sfn ${config.age.secrets.radicle-key.path} ${rad-home}/keys/radicle
    '';
  };

  # the bundle alone lives here. The api, the raw blobs and git over http all
  # belong to the seed, so no path has to be told apart from another and the
  # host holds one location. traefik owns 80 and 443 here, so nginx listens on
  # a local port only
  services.nginx.enable = true;
  services.nginx.virtualHosts.${web-domain} = {
    listen = [{
      addr = "127.0.0.1";
      port = web-port;
    }];
    root = explorer;
    # the client routes in the browser, so a path it owns is not a file and
    # has to come back as the bundle
    locations."/".tryFiles = "$uri $uri/ /index.html";
  };

  # the docker provider cannot see a host service, so both routes come from
  # the file provider, as the route of komodo does
  services.traefik.dynamicConfigOptions.http = {
    routers = {
      seed = {
        rule = "Host(`${seed-domain}`)";
        service = "seed";
      };
      git = {
        rule = "Host(`${web-domain}`)";
        service = "git";
      };
    };
    services = {
      seed.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString httpd-port}";
      }];
      git.loadBalancer.servers = [{
        url = "http://127.0.0.1:${toString web-port}";
      }];
    };
  };
}
