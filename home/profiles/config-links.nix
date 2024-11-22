{ config, lib, ... }: {
  options = {
    custom.config-links = with lib; mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the folder in flake:configs/ folder to be linked to destination";
          };
          dest = mkOption {
            type = types.str;
            description = "Path relative to HOME into which the folder will be linked";
          };
        };
      });
      default = [ ];
    };
  };
  config.home.file =
    let
      # this works when we're doing a local impure deploy from flake root
      live = builtins.getEnv "PWD";
      baked = ../../configs;
      mkLink =
        if live != "" then
          { name, dest }:
          let
            target = "${live}/configs/${name}";
            src =
              if builtins.pathExists target then
                config.lib.file.mkOutOfStoreSymlink target
              else
                "${baked}/${name}";
          in
          { "${dest}".source = src; }
        else { name, dest }: { "${dest}".source = "${baked}/${name}"; };
    in
    lib.mkMerge (map mkLink config.custom.config-links);
}
