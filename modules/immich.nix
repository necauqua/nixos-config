{ config, ... }: {
  services.immich = {
    enable = true;
    openFirewall = true;
    accelerationDevices = null; # null means "all"
    mediaLocation = "/storage/immich";
    settings = { };
    host = "127.0.0.1";
  };

  users.users.immich.extraGroups = [ "video" "render" ];

  custom.services = [
    { name = "immich"; port = config.services.immich.port; }
  ];
}
