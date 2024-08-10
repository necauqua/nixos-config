{ config, pkgs, ... }: {

  age.secrets.portunus = {
    file = ../secrets/portunus.age;
    owner = config.services.portunus.user;
  };

  services.portunus = {
    enable = true;
    domain = "sso.necauq.ua";
    port = 8168;
    seedSettings = {
      users =
        let
          read_pw = name: {
            from_command = [
              "${pkgs.jq}/bin/jq"
              "-r"
              ".${name}"
              config.age.secrets.portunus.path
            ];
          };
        in
        [
          {
            login_name = "bind";
            given_name = "Bind";
            family_name = "User";
            password = read_pw "bind";
          }
          {
            login_name = "anton";
            given_name = "Anton";
            family_name = "Bulakh";
            email = "him@necauq.ua";
            ssh_public_keys = config.users.users.root.openssh.authorizedKeys.keys;
            password = read_pw "anton";
          }
        ];
      groups = [
        {
          name = "search";
          long_name = "Can read LDAP";
          members = [ "bind" "anton" ];
          permissions.ldap.can_read = true;
        }
        {
          name = "portunus-admins";
          long_name = "Portunus Admins";
          members = [ "anton" ];
          permissions.portunus.is_admin = true;
        }
      ];
    };
    ldap = {
      searchUserName = "bind";
      tls = true;
      suffix = "dc=necauq,dc=ua";
    };
  };

  services.nginx.virtualHosts.${config.services.portunus.domain} = {
    enableACME = true; # this will create a separate cert from the main *.necauq.ua
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString config.services.portunus.port}";
  };

  networking.firewall.allowedTCPPorts = [ 636 ];
}
