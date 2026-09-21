{ config, pkgs, lib, ... }:

let
  # the bare repositories, one namespace per user and one per job inside it,
  # and the push target of the `jobs` user
  root = "/storage/jobs";
  # the worktree of each job, with the node_modules that the deploy installs,
  # next to the npm cache of its user
  work = "/var/lib/jobs";
  # the keys that the admin hands out. Root owns it, so nothing that runs as
  # `jobs` can grant itself one
  keys = "/var/lib/jobs-keys";
  hooks = "/etc/jobs/hooks";
  # The forced command of every key. The keys of root are written again on
  # every generation and could name the store, but the ones in the key file
  # outlive it, so both take the path that /etc keeps current
  gateway = "/etc/jobs/jobs-ssh";

  domain = "necauq.ua";
  ssh-port = lib.head config.services.openssh.ports;

  node = lib.getExe pkgs.nodejs;

  # the install and the build of a deploy, which jobs-timer starts inside a
  # sandbox because both run the code of the package
  jobs-install = pkgs.writeShellApplication {
    name = "jobs-install";
    runtimeInputs = with pkgs; [ jq nodejs ];
    text = builtins.readFile ./install.sh;
  };

  # The timers, the key file and the sandbox belong to root and the gateway
  # runs as `jobs`, so this is the one program that crosses between the two.
  # It takes names and never a unit or a path, so sudo can allow it whole
  jobs-timer = pkgs.writeShellApplication {
    name = "jobs-timer";
    runtimeInputs = with pkgs; [ jq openssh systemd ];
    text = ''
      ROOT=${root}
      WORK=${work}
      KEYS=${keys}
      GATEWAY=${gateway}
      INSTALL=${lib.getExe jobs-install}
    '' + builtins.readFile ./timer.sh;
  };

  post-receive = pkgs.writeShellApplication {
    name = "jobs-post-receive";
    runtimeInputs = with pkgs; [ git ];
    text = ''
      WORK=${work}
      SUDO=${config.security.wrapperDir}/sudo
      JOBS_TIMER=${lib.getExe jobs-timer}
    '' + builtins.readFile ./post-receive.sh;
  };

  jobs-ssh = pkgs.writeShellApplication {
    name = "jobs-ssh";
    runtimeInputs = with pkgs; [ git jq systemd ];
    text = ''
      ROOT=${root}
      WORK=${work}
      KEYS=${keys}
      HOOKS=${hooks}
      DOMAIN=${domain}
      SSH_PORT=${toString ssh-port}
      SUDO=${config.security.wrapperDir}/sudo
      JOBS_TIMER=${lib.getExe jobs-timer}
    '' + builtins.readFile ./ssh.sh;
  };
in
{
  users.users.jobs = {
    isSystemUser = true;
    group = "jobs";
    home = root;
    shell = pkgs.bashInteractive;
    # `log` and `status` read the journal of the units
    extraGroups = [ "systemd-journal" ];
    # the keys that reach the machine itself are the admin keys of the
    # gateway, in the "root" namespace
    openssh.authorizedKeys.keys = map
      (key: ''command="${gateway} root admin",restrict ${key}'')
      config.users.users.root.openssh.authorizedKeys.keys;
  };
  users.groups.jobs = { };

  # every other key is registered at run time, in a file that only root writes
  services.openssh.authorizedKeysFiles = [ "${keys}/%u" ];

  # the hooks and the gateway live outside the store, so a repository and a
  # registered key keep working across generations instead of pointing at a
  # path that garbage collection took
  environment.etc."jobs/hooks/post-receive".source = lib.getExe post-receive;
  environment.etc."jobs/jobs-ssh".source = lib.getExe jobs-ssh;

  security.sudo.extraRules = [{
    users = [ "jobs" ];
    runAs = "root";
    commands = [{
      command = lib.getExe jobs-timer;
      options = [ "NOPASSWD" ];
    }];
  }];

  systemd.tmpfiles.rules = [
    "d ${root} 0755 jobs jobs -"
    "d ${work} 0755 jobs jobs -"
    "d ${keys} 0755 root root -"
  ];

  # One instance per job. The instance holds the escaped "<user>/<job>", so
  # "%I" gives the path of the worktree back
  systemd.services."job@" = {
    description = "Scheduled job %I";
    serviceConfig = {
      Type = "oneshot";
      User = "jobs";
      Group = "jobs";
      WorkingDirectory = "${work}/%I";
      # the "main" field of package.json names the entry point
      ExecStart = "${node} .";

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      ReadWritePaths = [ "${work}/%I" ];

      # Every job runs as the same unix user, so the file modes cannot keep
      # one user away from another. The mount namespace does: the worktrees
      # of the others are behind an empty tmpfs and the repositories, which
      # no job ever needs, are not there at all
      InaccessiblePaths = [ root ];
      TemporaryFileSystem = [ "${work}:ro" ];
      BindPaths = [ "${work}/%I" ];

      # A job exists to call an api on a schedule, so the network stays open.
      # AF_NETLINK is in the list because glibc asks the kernel which address
      # families the machine has before it resolves a name
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" "AF_NETLINK" ];
    };
  };

  # The trigger itself comes from a drop-in that jobs-timer writes under /run,
  # out of the "onCalendar" field of the package. This value is only the
  # placeholder that lets the template load at all, and every instance that
  # runs has an override, because an instance without one is never started
  systemd.timers."job@" = {
    description = "Schedule of job %I";
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30s";
    };
  };

  # /run forgets the drop-ins on every boot, so they are written again from the
  # packages that are deployed
  systemd.services.jobs-arm = {
    description = "Arm the timer of every deployed job";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for tree in ${work}/*/*; do
        [ -f "$tree/package.json" ] || continue
        ${lib.getExe jobs-timer} arm \
          "$(basename "$(dirname "$tree")")" "$(basename "$tree")" || true
      done
    '';
  };
}
