{ pkgs, ... }: {
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

  networking.firewall.allowedTCPPorts = [ 8120 ];
}
