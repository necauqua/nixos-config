{ pkgs, lib, flake-inputs, features, ... }: {

  imports = with features; [
    flake-inputs.lanzaboote.nixosModules.lanzaboote
    configuration
    nvidia
    lan-audio
    samba
    arr
    borg
  ];

  networking.hostName = "main";

  boot = {
    bootspec.enable = true;
    loader.systemd-boot.enable = lib.mkForce false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-amd" ];
    kernelParams = [
      "libata.allow_tpm=1"
    ];
    zfs.extraPools = [ "archive" ];
  };

  # fix stupid steam hidpi
  environment.sessionVariables.STEAM_FORCE_DESKTOPUI_SCALING = "2";

  fileSystems = {
    "/" = {
      label = "main";
      fsType = "ext4";
    };
    "/boot" = {
      label = "boot";
      fsType = "vfat";
    };
    "/storage/games" = {
      label = "games";
      fsType = "btrfs";
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

  hardware = {
    # cooler control stuff
    gkraken.enable = true;

    enableRedistributableFirmware = true;
    cpu.amd.updateMicrocode = true;
  };

  # todo: maybe move this somewheree
  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };
}
