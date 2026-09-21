{ lib, config, flake-inputs, ... }:

let
  cfg = config.secrets;
in
{
  options.secrets = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
      options = {
        hash = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = ''
            The hash of the encrypted file, which changes on every edit of
            the secret because agenix encrypts with a fresh ephemeral key.

            Use it as a `restartTriggers` entry of a unit that reads the
            secret, so that the unit picks a rotated secret up. The path of
            the secret cannot do that: it is the same after a rotation, and
            the path of the encrypted file holds the whole flake, so it
            changes on every commit.
          '';
        };

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

      config.hash = builtins.hashFile "sha256" "${flake-inputs.self}/secrets/${name}.age";
    }));
  };

  config.age.secrets = lib.mapAttrs
    (name: secret: (
      { file = "${flake-inputs.self}/secrets/${name}.age"; }
      // lib.optionalAttrs (secret.mode != null) { inherit (secret) mode; }
      // lib.optionalAttrs (secret.owner != null) { inherit (secret) owner; }
      // lib.optionalAttrs (secret.group != null) { inherit (secret) group; }
      // lib.optionalAttrs (secret.path != null) { inherit (secret) path; }
    ))
    (lib.filterAttrs (_: s: s.enable) cfg);
}
