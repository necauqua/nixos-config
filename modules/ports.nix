{ lib, ... }:

let
  # the first port that is handed out. The range above it is free: it is over
  # every port that a service of this configuration picks by itself and under
  # the ephemeral range that the kernel gives to an outgoing connection
  base = 9000;
in
{
  # A port that only this machine uses does not have to be a number that
  # somebody chose. `ports.<name> = { }` claims one and `config.ports.<name>`
  # is the number it got, so the name is the only thing a module spells out.
  options.ports = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { });
    default = { };
    example = lib.literalExpression ''
      {
        ports.radicle-httpd = { };

        services.radicle.httpd.listenPort = config.ports.radicle-httpd;
      }
    '';
    # the claims of a machine are one attribute set, and the names of an
    # attribute set are sorted, so the same set of names always gives the same
    # ports
    apply = claims: lib.listToAttrs (lib.imap0
      (index: name: lib.nameValuePair name (base + index))
      (lib.attrNames claims));
    description = ''
      The local ports of this machine, by name. The names are numbered from
      ${toString base} up, therefore a claim that comes or goes moves the port
      of every name after it.

      Claim a port that nothing outside this machine has to know, such as the
      port of a service behind traefik or nginx. A port that a firewall rule,
      a peer, a client or a bookmark names stays a number in the module that
      owns it.
    '';
  };
}
