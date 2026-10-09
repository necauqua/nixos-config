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

  # cache.nixos.org has no unfree packages, so CUDA builds (ollama-cuda, obs
  # with cudaSupport) come from the cache of the nixpkgs CUDA team instead
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
  };
}
