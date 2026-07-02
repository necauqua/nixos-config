{ pkgs, lib, flake-inputs, features, ... }: {

  imports = with features; [
    flake-inputs.lanzaboote.nixosModules.lanzaboote
    configuration
    nvidia
    lan-audio
    samba
    borg
    obs
    niri
    emulation
    ollama
    mullvad
  ];

  networking = { hostName = "main"; hostId = "09e32be7"; };

  boot = {
    bootspec.enable = true;
    loader.systemd-boot.enable = lib.mkForce false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-amd" "msr" ];
    kernelParams = [ "libata.allow_tpm=1" "msr.allow_writes=on" ];
    zfs.extraPools = [ "games" ];
    supportedFilesystems = [ "nfs" ];
    binfmt = {
      emulatedSystems = [ "aarch64-linux" ];
      registrations.aarch64-linux.fixBinary = true;
      preferStaticEmulators = true;
    };
  };

  security.allowUserNamespaces = true;
  boot.kernel.sysctl = { "vm.nr_hugepages" = 3072; };

  environment.sessionVariables = {
    # fix stupid steam hidpi
    STEAM_FORCE_DESKTOPUI_SCALING = "2";
    # fix firefox+nvidia hwaccel
    MOZ_DISABLE_RDD_SANDBOX = "1";
  };

  fileSystems = {
    # Those folders (so, their datasets) are needed in initrd,
    # so we legacy-mount them here
    # (neededForBoot is not necessary for those specific ones)
    # Everything else is mounted by zfs
    "/" = { device = "main/root"; fsType = "zfs"; };
    "/nix" = { device = "main/nix"; fsType = "zfs"; };
    "/var" = { device = "main/var"; fsType = "zfs"; };
    # todo: not sure if log and lib are needed here specifically
    "/var/log" = { device = "main/var/log"; fsType = "zfs"; };
    "/var/lib" = { device = "main/var/lib"; fsType = "zfs"; };

    # and boot of course is on a separate vfat partition as well
    "/boot" = { label = "boot"; fsType = "vfat"; };

    "/storage" = {
      device = "home.lan:/storage";
      fsType = "nfs";
      options = [
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "x-systemd.mount-timeout=5s"
      ];
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";

  services.zfs.autoScrub.enable = true;

  # free up some cores to keep consuming that content
  # from the second monitor while packages are rebuilt
  nix.settings.max-jobs = 18;

  services = {
    xserver = {
      # force composition pipeline to fix screen tearing with nvidia
      # and also setup the screen positions I guess
      screenSection = ''
        Option "metamodes" "DP-2: nvidia-auto-select +1920+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, DP-5: nvidia-auto-select +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
      '';
      # previous xrandr setup to set screen positions
      # looks like it's still needed to set the primary screen
      displayManager.setupCommands = ''
        ${pkgs.xorg.xrandr}/bin/xrandr --output DP-2 --primary --right-of DP-5 || true;
      '';
    };
  };

  # allowing all rates like:
  # "default.clock.allowed-rates": [
  #   44100, 48000, 88200, 96000, 176400, 192000
  # ]
  # causes cracks when the rate switches (e.g commonly between 44.1 and 48)
  services.pipewire.extraConfig.pipewire.focusrite = {
    "context.properties" = {
      "default.clock.rate" = 192000;
    };
  };

  programs.coolercontrol.enable = true;

  hardware = {
    nvidia.open = false;
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  services.hardware.deepcool-digital-linux.enable = true;

  # cat likes to warm its butt on the radiator and keeps pressing the button omfg
  services.logind.settings.Login.HandlePowerKey = "ignore";

  services.acpid.handlers.power = {
    event = "button/power.*";
    action = ""; # noop
  };
}
