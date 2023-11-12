{ lib }: {

  load-modules = path:
    let
      pred = name: type:
        let
          isNix = type == "regular" && lib.hasSuffix ".nix" name;
          isNixDir = type == "directory" && builtins.pathExists (path + "/${name}/default.nix");
        in
        isNix || isNixDir;
    in
    lib.mapAttrs (name: _: path + "/${name}") (lib.filterAttrs pred (builtins.readDir path));
}
