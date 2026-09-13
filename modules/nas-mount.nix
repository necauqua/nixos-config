{
  fileSystems."/mnt/elastic-backups" = {
    device = "10.100.0.2:/storage/elastic-backups";
    fsType = "nfs";
    options = [
      "nfsvers=4.2"
      "_netdev"
      "noatime"
      # mount lazily on first access so a down VPN/NAS doesn't block boot
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=20"
    ];
  };

  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];
}
