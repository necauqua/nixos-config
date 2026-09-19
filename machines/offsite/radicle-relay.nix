{ ... }: {

  # home sits behind NAT, so the radicle node it runs announces itself as
  # seed.necauq.ua:8776 and is reached through this machine, which hands
  # the connection on over wireguard. The radicle protocol is not http, so
  # this is a stream proxy and not a virtual host
  services.nginx.streamConfig = ''
    server {
      listen 8776;
      listen [::]:8776;
      proxy_pass 10.100.0.2:8776;
      # a peer holds its connection open between announcements
      proxy_timeout 1h;
    }
  '';

  # the http side of the same name: the json api that a web client reads, the
  # raw blobs and git over http. traefik on home owns the name and picks the
  # route by the host header, which the proxy settings carry over, so this is
  # the very same hand-off that the home.necauq.ua hosts use
  services.nginx.virtualHosts."seed.necauq.ua" = {
    forceSSL = true;
    useACMEHost = "necauq.ua";
    locations."/" = {
      proxyPass = "http://10.100.0.2:8080";
      proxyWebsockets = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 8776 ];
}
