{ pkgs, config, ... }: {
  services = {
    samba = {
      enable = true;
      openFirewall = true;
      settings.global = {
        security = "user";
        workgroup = "WORKGROUP";

        "server string" = config.networking.hostName;
        "netbios name" = config.networking.hostName;

        "create mask" = "0664";
        "force create mode" = "0664";
        "directory mask" = "0775";
        "follow symlinks" = "yes";

        # note: localhost is the ipv6 localhost ::1
        "hosts allow" = "192.168.0.0/16 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
    };
    samba-wsdd = {
      enable = true;
      openFirewall = true;
    };
  };

  users = {
    groups.samba-guest = { };
    users.samba-guest = {
      isSystemUser = true;
      description = "Samba guest users";
      group = "samba-guest";
      home = "/var/empty";
      createHome = false;
      shell = pkgs.shadow;
    };
    users.necauqua.extraGroups = [ "samba-guest" ];
  };

  networking.firewall.allowPing = true;
}
