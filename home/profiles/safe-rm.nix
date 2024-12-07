{ config, lib, pkgs, ... }: {
  options.safe-rm = with lib; mkOption {
    type = types.bool;
    default = true;
  };
  config = {
    home.packages = with pkgs; [
      httm
      zfs-prune-snapshots
    ];
    programs.fish.functions.rm = lib.mkIf config.safe-rm {
      body = "${pkgs.httm}/bin/ounce --suffix pre-rm rm $argv";
      wraps = "rm";
    };
  };
}
