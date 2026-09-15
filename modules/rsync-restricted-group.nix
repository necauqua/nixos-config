{ pkgs, lib, ... }:
let
  # rrsync 3.5.0 pins every validated path by inode and hands rsync the bare
  # /proc/self/fd/N magic link.  A receiver destination that already exists as
  # a regular file then looks like a symlink to rsync, which tries to make way
  # for the new file with unlink() inside /proc/self/fd and gets EPERM, so an
  # upload can create a file but never replace one:
  #
  #   rsync: [generator] delete_file: unlink(4) failed: Operation not permitted
  #   could not make way for new regular file: 4
  #
  # The 3.4.4 script predates the inode pinning and does not have the fault.
  # Only the script comes from 3.4.4 -- it still runs the current rsync binary.
  rrsync = pkgs.rrsync.overrideAttrs (_: {
    version = "3.4.4";
    src = pkgs.fetchurl {
      url = "mirror://samba/rsync/src/rsync-3.4.4.tar.gz";
      hash = "sha256-vYjPgvplPaMjFPsikTZAfFyQ+A0XWNj0sJF2eHfY+pY=";
    };
    patches = [ ];
  });
in
{
  users.groups.rsync-restricted = { };
  services.openssh.extraConfig = ''
    Match Group rsync-restricted
      PermitTTY no
      X11Forwarding no
      AllowTcpForwarding no
      AllowAgentForwarding no
      ForceCommand ${lib.getExe rrsync} -wo .
  '';
}
