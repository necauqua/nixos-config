{ lib }: {

  load-modules = path:
    let
      pred = name: type:
        let
          isNix = type == "regular" && lib.hasSuffix ".nix" name;
          isNixDir = type == "directory" && builtins.pathExists (path + "/${name}/default.nix");
        in
        isNix || isNixDir;
      transform = name: _: {
        name = lib.removeSuffix ".nix" name;
        value = path + "/${name}";
      };
    in
    lib.mapAttrs' transform (lib.filterAttrs pred (builtins.readDir path));
}
