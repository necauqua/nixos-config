{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [ openssl ];
  networking.firewall.allowedTCPPorts = [ 8120 ];
}
