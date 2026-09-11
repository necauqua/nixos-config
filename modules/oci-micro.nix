{ pkgs, lib, modulesPath, ... }: {

  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "sd_mod" ];
    tmp.cleanOnBoot = true;

    # These boxes have no screen, and OCI's interactive serial console refuses
    # to connect, so the captured console history is the only way to watch a
    # boot. Without this everything goes to the invisible VGA console and a
    # failed boot looks exactly like a dead machine.
    kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

    # The cloud image keeps /boot on its own 913 MB ext4 partition and a 106 MB
    # ESP at /boot/efi. systemd-boot would have to fit every generation's kernel
    # and initrd into that ESP, so GRUB is used instead: it keeps them on /boot
    # and puts only the loader on the ESP. OCI does not persist NVRAM entries
    # across a boot volume restore, hence efiInstallAsRemovable.
    loader = {
      efi.efiSysMountPoint = "/boot/efi";
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
        configurationLimit = 10;
        # Appended after the generated gfxterm setup, so it wins: GRUB's menu
        # and its error messages go to the serial port too.
        extraConfig = ''
          serial --unit=0 --speed=115200
          terminal_input serial console
          terminal_output serial console
        '';
      };
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/cloudimg-rootfs";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-label/BOOT";
      fsType = "ext4";
    };
    "/boot/efi" = {
      device = "/dev/disk/by-label/UEFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  swapDevices = [{
    device = "/swapfile";
    size = 4096;
  }];

  networking = {
    useDHCP = lib.mkDefault true;
    firewall.enable = true;
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  time.timeZone = "Europe/Kyiv";
  i18n.defaultLocale = "en_US.UTF-8";

  nix = {
    settings = {
      max-jobs = 1;
      cores = 1;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  services = {
    endlessh = {
      enable = true;
      port = 22;
      openFirewall = true;
      extraOptions = [ "-vd" "999999" ];
    };
    openssh = {
      enable = true;
      ports = [ 5555 ];
      openFirewall = true;
      settings.PasswordAuthentication = false;
    };
    journald.extraConfig = "SystemMaxUse=100M";
  };

  programs.fish.enable = true;

  users = {
    mutableUsers = false;
    defaultUserShell = pkgs.fish;
    users =
      let
        keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL0oajjYx0nt7A2zBWjnc5gxTs1nBcGHuGNyp0Al5rAz openpgp:0xA61191F9"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoNFwj1SN1LJGT6Pto7hp9kHhWF9RsF0tXMI95Jix5P phone"
        ];
      in
      {
        root.openssh.authorizedKeys.keys = keys;
        necauqua = {
          isNormalUser = true;
          extraGroups = [ "wheel" "docker" ];
          hashedPassword = "$6$.fpv9TmqXoHSfmj/$ql9VtGHMsyJssreJY0lTINfQkYZSZZnDzAozje4R1jWiih92I.QlHbjmfPeRexBjEM4VfZseEo4R5id/OkK9a1";
          openssh.authorizedKeys.keys = keys;
        };
      };
  };

  environment.systemPackages = with pkgs; [
    git
    helix
    htop
  ];

  system.stateVersion = "26.05";
}
