{ config, lib, ... }: {

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = lib.mkDefault true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # huh
  environment.variables.LIBVA_DRIVER_NAME = lib.mkDefault "nvidia";

  hardware.nvidia-container-toolkit.enable = config.virtualisation.docker.enable || config.virtualisation.podman.enable;

  # seems like the above enable actually does nothing without this, upstream oopsie?
  virtualisation.docker.enableNvidia = config.virtualisation.docker.enable || config.virtualisation.podman.enable;
}
