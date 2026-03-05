{ pkgs, features, flake-inputs, ... }: {

  imports = with features; [
    nix-flakes
    nix-config
    nvidia
    flake-inputs.docker-zfs-plugin.nixosModules.docker-zfs-plugin
  ];

  boot = {
    kernelParams = [ "zfs.zfs_arc_max=17179869184" ]; # limit ARC to 16GB
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-intel" ];
    supportedFilesystems = [ "zfs" ];
    zfs.extraPools = [ "storage" ];

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  fileSystems = {
    "/" = {
      # device = "/dev/disk/by-label/nix";
      device = "/dev/disk/by-uuid/0b2f87a7-e43d-4139-b11d-9bc2db393100";
      fsType = "ext4";
    };
    "/boot" = {
      # device = "/dev/disk/by-label/BOOT";
      device = "/dev/disk/by-uuid/F514-94ED";
      fsType = "vfat";
      options = [ "fmask=0077" ];
    };
  };

  networking = {
    hostId = "7eab6820"; # zfs
    hostName = "home";
    networkmanager.enable = true;

    firewall.allowedTCPPorts = [ 80 443 2049 ]; # http(s) and nfs
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.fish.enable = true;

  users = {
    defaultUserShell = pkgs.fish;
    users = {
      root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoNFwj1SN1LJGT6Pto7hp9kHhWF9RsF0tXMI95Jix5P phone"
      ];
      necauqua = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        hashedPassword = "$6$.fpv9TmqXoHSfmj/$ql9VtGHMsyJssreJY0lTINfQkYZSZZnDzAozje4R1jWiih92I.QlHbjmfPeRexBjEM4VfZseEo4R5id/OkK9a1";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoNFwj1SN1LJGT6Pto7hp9kHhWF9RsF0tXMI95Jix5P phone"
        ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    git
    helix
    htop
  ];

  hardware.graphics.enable32Bit = true;
  hardware.nvidia.open = false; # 1650 SUPER

  virtualisation.docker = {
    enable = true;
    daemon.settings.features.cdi = true;
  };

  services = {
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };
    zfs.autoScrub.enable = true;
    nfs.server.enable = true;
    docker-zfs-plugin = {
      enable = true;
      datasets = [ "storage/volumes" ];
      mountDir = "/storage/volumes"; # docker-zfs-plugin (this fork of it) manages mounts itself to avoid boot ordering issues
    };
  };

  system.stateVersion = "24.11";
}
