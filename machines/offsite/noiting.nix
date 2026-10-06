{ config, lib, pkgs, ... }:
let
  domain = "noit.ing";
  # the host side of the container, which nginx alone reaches
  port = config.ports.noiting;

  # the data directory of the container: the SQLite database and its WAL
  data = "/storage/noiting";
  db = "${data}/noiting.db";

  # a ZFS dataset on home, exported like storage/elastic-backups
  # (sharenfs="rw=@10.100.0.0/24,no_root_squash,sec=sys")
  backups = "/mnt/noiting-backups";

  # A consistent copy of the database every 5 minutes, compressed, on home.
  # VACUUM INTO gives the same bytes for the same content, so a copy that is
  # the same as the last one is not kept. The retention keeps all copies of
  # the last 2 hours, the newest copy of each hour for 48 hours and the newest
  # copy of each day for 30 days. The newest copy always stays, also when the
  # database did not change for a long time.
  #
  # Restore: stop docker-noiting, remove noiting.db, noiting.db-wal and
  # noiting.db-shm from the data directory, `zstd -d` a copy to noiting.db,
  # start docker-noiting.
  noiting-backup = pkgs.writeShellApplication {
    name = "noiting-backup";
    runtimeInputs = with pkgs; [ coreutils diffutils findutils sqlite zstd ];
    text = ''
      db=${db}
      dest=${backups}
      # CacheDirectory of the unit: the last copy, for the comparison
      cache=$CACHE_DIRECTORY

      new=$cache/new.db
      last=$cache/last.db

      if [ ! -f "$db" ]; then
        echo "no database yet, the container did not start"
        exit 0
      fi

      rm -f "$new"
      sqlite3 -readonly "$db" ".timeout 10000" "VACUUM INTO '$new'"

      # the last copy counts only while home still has a copy
      if [ -f "$last" ] && cmp -s "$new" "$last" \
        && [ -n "$(find "$dest" -maxdepth 1 -name 'noiting-*.db.zst' -print -quit)" ]; then
        rm -f "$new"
      else
        name=noiting-$(date -u +%Y%m%dT%H%MZ).db.zst
        zstd -q -f "$new" -o "$dest/.$name.tmp"
        mv "$dest/.$name.tmp" "$dest/$name"
        mv "$new" "$last"
      fi

      # the names sort by time, so the first file of each hour and of each day
      # is the newest one of it
      now=$(date -u +%s)
      declare -A hours=() days=()
      newest=1
      while IFS= read -r file; do
        stamp=''${file#noiting-}
        stamp=''${stamp%.db.zst}
        time=$(date -u -d "''${stamp:0:8} ''${stamp:9:2}:''${stamp:11:2}" +%s)
        age=$((now - time))
        hour=''${stamp:0:11}
        day=''${stamp:0:8}

        keep=$newest
        newest=
        if [ "$age" -lt $((2 * 3600)) ]; then
          keep=1
        fi
        if [ -z "''${hours[$hour]:-}" ]; then
          hours[$hour]=1
          if [ "$age" -lt $((48 * 3600)) ]; then keep=1; fi
        fi
        if [ -z "''${days[$day]:-}" ]; then
          days[$day]=1
          if [ "$age" -lt $((30 * 86400)) ]; then keep=1; fi
        fi

        if [ -z "$keep" ]; then
          rm -f -- "''${dest:?}/$file"
        fi
      done < <(find "$dest" -maxdepth 1 -name 'noiting-*.db.zst' -printf '%f\n' | sort -r)

      # the partial file of a copy that failed
      find "$dest" -maxdepth 1 -name '.noiting-*.tmp' -mmin +60 -delete
    '';
  };
in
{
  ports.noiting = { };

  # NOITING_TWITCH_CLIENT_ID and NOITING_TWITCH_CLIENT_SECRET
  secrets.noiting = { };

  # Not managed here: the image. The `deploy` script of the noit-ing repo
  # builds it, loads it into docker as localhost/noiting:latest and restarts
  # the container. The image that was there before is localhost/noiting:previous
  virtualisation.oci-containers = {
    backend = "docker";
    containers.noiting = {
      image = "localhost/noiting:latest";
      pull = "never";
      ports = [ "127.0.0.1:${toString port}:8080" ];
      volumes = [ "${data}:/data" ];
      environment.NOITING_CLIENT_IP_HEADER = "X-Real-IP";
      environmentFiles = [ config.age.secrets.noiting.path ];
    };
  };

  systemd.services.docker-noiting.restartTriggers = [ config.secrets.noiting.hash ];

  systemd.tmpfiles.rules = [ "d ${data} 0750 root root -" ];

  fileSystems.${backups} = {
    device = "10.100.0.2:/storage/noiting-backups";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "_netdev"
      "noatime"
      # a missing home fails the backup with an error, and does not freeze it
      "soft"
      "timeo=100"
      "retrans=3"
      # mount lazily on first access so a down VPN/NAS doesn't block boot
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=20"
    ];
  };

  systemd.services.noiting-backup = {
    description = "Copy the noit.ing database to home";
    onFailure = [ "noiting-backup-failed.service" ];
    unitConfig.RequiresMountsFor = [ backups ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe noiting-backup;
      CacheDirectory = "noiting-backup";
      TimeoutStartSec = "4min";
    };
  };

  systemd.timers.noiting-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      Persistent = true;
    };
  };

  systemd.services.noiting-backup-failed = {
    description = "Report a failed noit.ing backup";
    serviceConfig.Type = "oneshot";
    script = ''
      /run/current-system/sw/bin/tg-alert "noit.ing: the database backup to home failed on offsite, see \`journalctl -u noiting-backup\`"
    '';
  };

  # the admin flag, and other changes by hand: sqlite3 ${db}
  environment.systemPackages = [ pkgs.sqlite ];

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    enableACME = true;
    locations = {
      "/".proxyPass = "http://127.0.0.1:${toString port}";
      # the live event stream (SSE): each event must go out at once
      "= /live" = {
        proxyPass = "http://127.0.0.1:${toString port}";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 1h;
        '';
      };
      "/brine".extraConfig = ''
        return 302 https://twitch.tv/team/brinesquad;
      '';
    };
  };
}
