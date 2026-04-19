{ lib, config, inputs, ... }:

let
  cfg = config.secrets;
in
{
  imports = [
    inputs.agenix.nixosModules.age
  ];
  options.secrets = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Allows conditionally disabling the secret";
        };

        mode = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };

        owner = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };

        group = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };

        path = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    });
  };

  config.age.secrets = lib.mapAttrs
    (name: secret: (
      { file = "${inputs.self}/secrets/${name}.age"; }
      // lib.optionalAttrs (secret.mode != null) { inherit (secret) mode; }
      // lib.optionalAttrs (secret.owner != null) { inherit (secret) owner; }
      // lib.optionalAttrs (secret.group != null) { inherit (secret) group; }
      // lib.optionalAttrs (secret.path != null) { inherit (secret) path; }
    ))
    (lib.filterAttrs (_: s: s.enable) cfg);
}
