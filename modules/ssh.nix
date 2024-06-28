{
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoNFwj1SN1LJGT6Pto7hp9kHhWF9RsF0tXMI95Jix5P phone"
  ];
  services.openssh = {
    enable = true;
    ports = [ 5555 ];
    openFirewall = true;
    settings.PasswordAuthentication = false;
  };
  services.endlessh = {
    enable = true;
    port = 22;
    openFirewall = true;
    extraOptions = [ "-vd" "999999" ];
  };
}
