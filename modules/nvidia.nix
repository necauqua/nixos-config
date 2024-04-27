{ config, lib, ... }: {

  services.xserver.videoDrivers = lib.optional config.services.xserver.enable "nvidia";

  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;

  # huh
  environment.variables.LIBVA_DRIVER_NAME = "nvidia";

  virtualisation.docker.enableNvidia = config.virtualisation.docker.enable;
}
