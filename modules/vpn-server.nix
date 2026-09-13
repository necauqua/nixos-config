let
  port = 51820;
in
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.firewall = {
    allowedUDPPorts = [ port ];
    trustedInterfaces = [ "wg0" ];
  };

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.1/24" ];
    listenPort = port;
    privateKeyFile = "/etc/wireguard/self.key";

    peers = [
      # NAS peer
      {
        publicKey = "bwagHKQlCYMLNu0Cq+er5xG76IViBddDYD56cJ8M/gc=";
        # Server can reach NAS's WG IP AND the whole LAN via NAS
        allowedIPs = [ "10.100.0.2/32" "192.168.1.0/24" ];
        # persistentKeepalive = 25;
      }
    ];
  };
}
