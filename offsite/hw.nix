{ modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub.device = "/dev/disk/by-id/wwn-0x5002538e308356ac";
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/859f823c-f9ac-41a4-9e67-d546dbe8f4f4";
    fsType = "ext4";
  };
  fileSystems."/storage" = {
    device = "/dev/disk/by-uuid/23c4a0b5-0c4e-4c00-8cf2-1eb672a9bae9";
    fsType = "ext4";
  };
}
