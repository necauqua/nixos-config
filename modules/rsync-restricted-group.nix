{ pkgs, lib, ... }: {
  users.groups.rsync-restricted = { };
  services.openssh.extraConfig = ''
    Match Group rsync-restricted
      PermitTTY no
      X11Forwarding no
      AllowTcpForwarding no
      AllowAgentForwarding no
      ForceCommand ${lib.getExe pkgs.rrsync} -wo .
  '';
}
