{ config, ... }:
let
  cfg = config.services.portunus;
in
{

  age.secrets.ldap-bind-password = {
    file = ../secrets/ldap-bind-password.age;
    owner = cfg.user;
  };
  age.secrets.ldap-anton-password = {
    file = ../secrets/ldap-anton-password.age;
    owner = cfg.user;
  };

  services.portunus = {
    enable = true;
    domain = "sso.necauq.ua";
    port = 8168;
    seedSettings =
      let
        read_pw = name: {
          from_command = [ "cat" config.age.secrets."ldap-${name}-password".path ];
        };
        group = name: long_name: {
          inherit name long_name;
          members = [ "anton" ];
        };
      in
      {
        users = [
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
          (group "jellyfin-admins" "Jellyfin Admins")
        ];
      };
    ldap = {
      searchUserName = "bind";
      tls = true;
      suffix = "dc=necauq,dc=ua";
    };
  };

  services.nginx.virtualHosts.${cfg.domain} = {
    # this will create a separate cert from the main *.necauq.ua,
    # that will be used by the services.portunus definition
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port}";
  };

  networking.firewall.allowedTCPPorts = [ 636 ];
}
