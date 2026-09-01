{ config, lib, ... }: {

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = lib.mkDefault true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # huh
  environment.variables.LIBVA_DRIVER_NAME = lib.mkDefault "nvidia";

  # containers get the GPU through CDI, so they need an explicit
  # `--device=nvidia.com/gpu=all` - there is no nvidia default runtime
  hardware.nvidia-container-toolkit.enable = config.virtualisation.docker.enable || config.virtualisation.podman.enable;
}
