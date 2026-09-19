{ config, lib, ... }:
let
  cfg = config.custom.config-links;
in
{
  options.custom.config-links = {
    live = lib.mkOption {
      type = with lib.types; nullOr str;
      default =
        if config.headless then
          null
        else
          "${config.home.homeDirectory}/projects/nixos-config";
      example = "/home/necauqua/projects/nixos-config";
      description = ''
        Absolute path of this flake checkout on the target machine.

        When it is set, every link points straight into that checkout, so an
        edit applies to the program immediately and needs no rebuild. When it
        is null, the folders of configs/ go into the store and the links point
        there instead.
      '';
    };

    links = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Name of the folder in the configs/ folder of the flake.";
          };
          dest = lib.mkOption {
            type = lib.types.str;
            description = "Path relative to HOME into which the folder is linked.";
          };
        };
      });
      default = [ ];
      description = "Config folders to link out of the flake into HOME.";
    };
  };

  config = {
    home.file = lib.mkMerge (map
      ({ name, dest }: {
        ${dest}.source =
          if cfg.live != null then
            config.lib.file.mkOutOfStoreSymlink "${cfg.live}/configs/${name}"
          else
          # a relative path keeps the store copy down to this one folder
            ../../configs + "/${name}";
      })
      cfg.links);

    # a live path is a promise about the target machine, so tell the user when
    # the promise is broken instead of leaving dangling links behind
    home.activation = lib.mkIf (cfg.live != null && cfg.links != [ ]) {
      checkConfigLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        if [ ! -d ${lib.escapeShellArg "${cfg.live}/configs"} ]; then
          warnEcho "custom.config-links: ${cfg.live}/configs is missing, the links stay dangling"
        fi
      '';
    };
  };
}
