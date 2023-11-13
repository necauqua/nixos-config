{ config, lib, ... }: {

  services.xserver.videoDrivers = lib.optional config.services.xserver.enable "nvidia";

  hardware.nvidia.modesetting.enable = true;

  # huh
  environment.variables.LIBVA_DRIVER_NAME = "nvidia";

  virtualisation.docker.enableNvidia = config.virtualisation.docker.enable;
}
