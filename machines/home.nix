{ pkgs, features, ... }: {

  imports = with features; [
    nix-flakes
    nix-config
    nginx
    immich
  ];

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "zfs" ];
    zfs.extraPools = [ "storage" ];

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nix";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "vfat";
      options = [ "fmask=0077" ];
    };
  };

  networking = {
    hostId = "7eab6820"; # zfs
    hostName = "home";
    networkmanager.enable = true;

    firewall.allowedTCPPorts = [ 2049 ]; # nfs
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.fish.enable = true;

  users = {
    defaultUserShell = pkgs.fish;
    users.necauqua = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      hashedPassword = "$6$.fpv9TmqXoHSfmj/$ql9VtGHMsyJssreJY0lTINfQkYZSZZnDzAozje4R1jWiih92I.QlHbjmfPeRexBjEM4VfZseEo4R5id/OkK9a1";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    helix
    htop
  ];

  services = {
    openssh.enable = true;
    zfs.autoScrub.enable = true;
    nfs.server = {
      enable = true;
      # exports = ''
      #   /storage 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash,fsid=0)
      # '';
    };
  };

  system.stateVersion = "24.11";
}
