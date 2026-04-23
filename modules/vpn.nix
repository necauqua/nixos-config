{ pkgs, ... }:
let
  iface = "enp3s0";
in
{
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.firewall.trustedInterfaces = [ "wg0" ];

  networking.wireguard.interfaces.wg0 = {
    ips = [ "10.100.0.2/24" ];
    privateKeyFile = "/etc/wireguard/self.key";

    peers = [
      {
        endpoint = "necauq.ua:51820";
        publicKey = "SW8cdpRVRxHxWkmDrhCwmlV4SujboJM4DLwF1IiafVM=";
        # Only server's WG IP routed through tunnel — LAN traffic stays local
        allowedIPs = [ "10.100.0.1/32" ];
        persistentKeepalive = 25; # important: we're behind NAT
      }
    ];

    # vibecode alert: I kinda lack networking knowledge to know how tf
    # iptables actually work, however this should be a very common setup
    # and is also testable aka if it works it works

    # NAT traffic coming from server (10.100.0.0/24) onto the LAN
    # so LAN hosts reply to the NAS, not to an unknown 10.100.0.x
    postSetup = ''
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING \
        -s 10.100.0.0/24 -d 192.168.1.0/24 -o ${iface} -j MASQUERADE
    '';
    postShutdown = ''
      ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING \
        -s 10.100.0.0/24 -d 192.168.1.0/24 -o ${iface} -j MASQUERADE
    '';
  };
}
