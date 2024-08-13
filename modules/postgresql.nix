{ pkgs, lib, ... }: {
  services.postgresql = {
    # # should have enable=true in every module that needs it
    # enable = true;

    # pin the major version
    package = pkgs.postgresql_16;
    # setup peer auth
    authentication = lib.mkOverride 10 ''
      local all all trust
    '';
  };
}
