{ lib, pkgs, ... }: {
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # /var/lib/ollama is a zfs dataset, dont do the whole `private` symlink thing with DynamicUser
    user = "ollama";
  };
  # same
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;
}
