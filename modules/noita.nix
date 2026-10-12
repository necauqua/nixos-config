{ config, pkgs, lib, ... }:
let
  cfg = config.noita;

  save = "$HOME/.local/share/Steam/steamapps/compatdata/881100/pfx/drive_c/users/steamuser/AppData/LocalLow/Nolla_Games_Noita/save00";

  # decrypts the .salakieli files from stdin to stdout
  cipher = "openssl enc -d -aes-128-ctr"
    + " -K 536563726574734f66546865416c6c53"
    + " -iv 54687265654579657341726557617463";

  noita-stats = pkgs.writeShellApplication {
    name = "noita-stats";
    runtimeInputs = with pkgs; [ jq yq-go openssl ];
    text = ''
      if [ -f "${save}/stats/_streaks.salakieli" ]; then
          echo "streak=$(${cipher} < "${save}/stats/_streaks.salakieli" \
              | yq -p xml '.GameStreaks.+@current_streak_count // 0')"
      else
          echo streak=0
      fi

      stats=$(${cipher} < "${save}/stats/_stats.salakieli" | yq -p xml -o json .GameStats)

      echo "wins=$(echo "$stats" | jq -r '.KEY_VALUE_STATS.E | map({ key: ."+@key", value: ."+@value" }) | from_entries | ((.progress_ending0 // 0 | tonumber) + (.progress_ending1 // 0 | tonumber))')"
      echo "deaths=$(echo "$stats" | jq -r '.global["+@death_count"] // 0')"
      echo "pb=$(echo "$stats" | jq -r '.highest["+@streaks"] // 0')"
    '';
  };

  noita-snapshot = pkgs.writeShellApplication {
    name = "noita-snapshot";
    runtimeInputs = [ config.boot.zfs.package noita-stats ];
    # the variables come from the eval of the noita-stats output
    excludeShellChecks = [ "SC2154" ];
    text = ''
      if [ $# -gt 1 ]; then
          echo "Usage: noita-snapshot [name]" >&2
          exit 1
      fi

      # a named snapshot is always made, with exactly that name
      if [ $# -eq 1 ]; then
          zfs snapshot "${cfg.saveDataset}@$1"
          exit
      fi

      # only our own auto-* snapshots count, sanoid's autosnap_* ones are ignored, sanoid's autosnap_* ones are ignored
      last=$(zfs list -Hp -d 1 -t snapshot -o name -s creation "${cfg.saveDataset}" | grep '@auto-' | tail -1 || true)
      if [ -n "$last" ] && [ "$(zfs get -Hp -o value "written@''${last#*@}" "${cfg.saveDataset}")" = 0 ]; then
          echo "Skipping empty snapshot"
      else
          eval "$(noita-stats)"
          zfs snapshot "${cfg.saveDataset}@auto-$deaths-$wins-$streak-$pb.$(date +%FT%TZ)"
      fi
    '';
  };

  noita-list = pkgs.writeShellApplication {
    name = "noita-list";
    runtimeInputs = [ config.boot.zfs.package ];
    text = ''
      # all snapshots except the sanoid autosnap_* ones
      zfs list -r "${cfg.saveDataset}" -t snapshot "$@" | grep -v '@autosnap_'
    '';
  };

  noita = pkgs.writeShellApplication {
    name = "noita";
    runtimeInputs = [ noita-snapshot ];
    text = ''
      noita-snapshot
      exec ${lib.getExe config.programs.steam.package} steam://rungameid/881100
    '';
  };

  desktop-item = pkgs.makeDesktopItem {
    name = "Noita";
    desktopName = "Noita";
    comment = "Make a snapshot of the save and then play this game on Steam";
    exec = lib.getExe noita;
    icon = "steam_icon_881100"; # installed by steam
    categories = [ "Game" ];
  };
in
{
  options.noita.saveDataset = lib.mkOption {
    type = lib.types.str;
    example = "main/noita-save";
    description = ''
      The zfs dataset that is mounted on the Noita save00 folder.
      The user must have the zfs mount and snapshot permissions on it.
    '';
  };

  config = {
    environment.systemPackages = [ noita noita-stats noita-snapshot noita-list ];

    # steam writes its own Noita.desktop here, force replaces it
    home-manager.users.necauqua.xdg.dataFile."applications/Noita.desktop" = {
      source = "${desktop-item}/share/applications/Noita.desktop";
      force = true;
    };
  };
}
