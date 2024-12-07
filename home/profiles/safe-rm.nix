{ config, lib, pkgs, ... }: {
  options.safe-rm = with lib; mkOption {
    type = types.bool;
    default = true;
  };
  config = {
    home.packages = with pkgs; lib.optionals config.safe-rm [
      httm
      zfs-prune-snapshots
    ];
    programs.fish.functions.rm = lib.mkIf config.safe-rm {
      body = ''
        ${pkgs.httm}/bin/ounce --suffix pre-rm rm $argv
        set -l st $status
        set -l snap $(zfs list -t snapshot -o name -HS creation | head -1)
        echo -e "rm $argv | ref $snap" >> ~/.rm-history
        return $st
      '';
      wraps = "rm";
    };
  };
}
