{ modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    loader.grub.device = "/dev/disk/by-id/wwn-0x50014ee059afcbb6";
    initrd = {
      availableKernelModules = [ "ata_piix" "uhci_hcd" "xen_blkfront" "vmw_pvscsi" ];
      kernelModules = [ "nvme" ];
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/49648b41-bb27-4a47-b874-235d61f417f3";
      fsType = "ext4";
    };
    "/storage" = {
      device = "/dev/disk/by-uuid/ec50ec1f-538c-4561-8c4c-989c1c70233c";
      fsType = "ext4";
    };
  };
}
