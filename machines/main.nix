{ pkgs, lib, flake-inputs, features, ... }: {

  imports = with features; [
    flake-inputs.lanzaboote.nixosModules.lanzaboote
    configuration
    nvidia
    lan-audio
    samba
    arr
    borg
    nginx
    obs
    xorg
    emulation
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
    kernelModules = [ "kvm-amd" ];
    kernelParams = [ "libata.allow_tpm=1" ];
    zfs.extraPools = [ "bulk" ];
  };

  # fix stupid steam hidpi
  environment.sessionVariables.STEAM_FORCE_DESKTOPUI_SCALING = "2";

  fileSystems = {
    # Those folders (so, their datasets) are needed in initrd,
    # so we legacy-mount them here
    # (neededForBoot is not necessary for those specific ones)
    # Everything else is mounted by zfs
    "/" = { device = "main/root"; fsType = "zfs"; };
    "/nix" = { device = "main/nix"; fsType = "zfs"; };
    "/var" = { device = "main/var/_"; fsType = "zfs"; };
    "/var/log" = { device = "main/var/log"; fsType = "zfs"; };
    "/var/lib" = { device = "main/var/lib/_"; fsType = "zfs"; };

    # and boot of course is out-of-zfs on a separate partition
    "/boot" = { label = "boot"; fsType = "vfat"; };
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
      # "default.configured.audio.source".name = "SF_mono_in";
    };
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = "Microphone";
          "capture.props" = {
            "node.name" = "capture.SF_stereo_in";
            "audio.position" = [ "FL" ];
            "node.target" = "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y8CQA1U1573F7C-00.pro-output-0";
            "stream.dont-remix" = true;
            "node.passive" = true;
          };
          "playback.props" = {
            "node.name" = "SF_mono_in";
            "media.class" = "Audio/Source";
            "audio.position" = [ "MONO" ];
          };
        };
      }
    ];
  };

  programs.coolercontrol = {
    enable = true;
    nvidiaSupport = true;
  };
  hardware = {
    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  # todo: maybe move this somewheree
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    # /var/lib/ollama is a zfs dataset, dont do the whole `private` symlink thing with DynamicUser
    user = "ollama";
  };
  # same
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;

  # cat likes to warm its butt on the radiator and keeps pressing the button omfg
  services.logind.powerKey = "ignore";
}
