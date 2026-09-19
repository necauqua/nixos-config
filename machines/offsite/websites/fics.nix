{ pkgs, ... }:
let
  dir = "/var/www/fics.necauq.ua";
in
{
  users.users.fics-deployer = {
    isNormalUser = true;
    shell = pkgs.dash;
    home = dir;
    # nginx must be able to traverse and read the served files; the default
    # 0700 home mode is re-applied by user activation after systemd-tmpfiles
    homeMode = "755";
    group = "rsync-restricted";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN/7hjf5aHeQ0vjCJ6qmXFS2gG1pCYCp2u9/FHXuOMcc fics-deployer"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
    ];
  };
  services.nginx.virtualHosts."fics.necauq.ua" = {
    forceSSL = true;
    useACMEHost = "necauq.ua";
    extraConfig = ''
      root ${dir};
      index index.html;
      error_page 404 /404.html;
    '';
    locations."/".tryFiles = "$uri $uri.html $uri/ =404";
  };
}
