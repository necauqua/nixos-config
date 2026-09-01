{ pkgs, lib, features, flake-inputs, ... }: {

  imports = with features; [
    nix-flakes
    nix-config
    nvidia
    flake-inputs.docker-zfs-plugin.nixosModules.docker-zfs-plugin
    vpn
  ];

  boot = {
    kernelParams = [
      "zfs.zfs_arc_max=12884901888" # limit ARC to 12GB

      # those two params *probably* help with weird traceless complete lockups I've been getting,
      # at least according to LLMs
      "pcie_aspm=off"
      "intel_idle.max_cstate=1"
    ];
    kernel.sysctl = {
      "kernel.panic" = 10; # reboot after 10s instead of freezing
      "vm.overcommit_memory" = 1; # redis wants this
    };
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-intel" "netconsole" ];
    supportedFilesystems = [ "zfs" ];
    zfs.extraPools = [ "storage" ];
    # set explicitly because of old stateVersion, this is the new default
    zfs.forceImportRoot = false;

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  # enable hardware watchdog to reset the box once one of those stupid hangs happen
  # while still no clue what exactly causes those (fixing fans helped a lot, but it still happens sometimes)
  # the watchdog resets reduced downtime from "many hours/days until I manually reset it" to ~90s
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "30s";
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

  # Pull from main's /nix/store first: main is a beefy desktop that builds a
  # lot, so query it as a fast LAN substituter before hitting the public caches.
  # No signing key is set up, so only paths that already carry a trusted
  # signature (e.g. cache.nixos.org origin) are accepted; main's own local
  # builds won't be fetched. If main is offline the substitution just fails
  # silently and the next substituter is used.
  nix.settings.substituters = lib.mkBefore [
    "ssh-ng://necauqua@main.lan?ssh-key=/etc/ssh/ssh_host_ed25519_key&priority=10"
  ];
  # trust main's host key so the nix-daemon's ssh connection isn't blocked on
  # interactive host-key verification (value from secrets/secrets.nix)
  programs.ssh.knownHosts."main.lan".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICX06Kpfqdi67PsxLTKPZaBeXhMp4rAV1ea2m3KDbuo+";

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
