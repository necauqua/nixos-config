{ config, lib, pkgs, ... }: {
  environment.systemPackages = [ pkgs.openssl ];

  services.komodo-periphery = {
    enable = true;
    inbound.ssl.enable = false;
    auth.corePublicKeys = [
      "MCowBQYDK2VuAyEArzAkUWZSVkkMmhgsxvxtoOeDxoLAn0s+pDPlw9NM6zU="
    ];
  };

  # it actually needs docker and git on PATH, weird that nixos module does not
  # have this
  systemd.services.komodo-periphery.path = with pkgs; [
    docker
    docker-compose
    git
  ];

  # core reaches the agent from the outside here, but on the machine that runs
  # core itself the agent stays on the loopback interface
  networking.firewall.allowedTCPPorts =
    lib.optional (config.services.komodo-periphery.inbound.bindIp != "127.0.0.1") 8120;
}
