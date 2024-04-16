{ pkgs, lib, flake-inputs, modules, ... }: {

  imports = with modules; [
    flake-inputs.lanzaboote.nixosModules.lanzaboote
    configuration
    nvidia
    lan-audio
    samba
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
    "/" =
      {
        device = "/dev/disk/by-uuid/2b2115f8-864f-4482-9e0d-a0211be2e40c";
        fsType = "ext4";
      };
    "/boot" =
      {
        device = "/dev/disk/by-uuid/C995-FAC3";
        fsType = "vfat";
      };
    "/storage/games" =
      {
        device = "/dev/disk/by-uuid/f1ab243a-0c71-4671-9eeb-7b34c6610ddd";
        fsType = "ext4";
      };
    "/storage/secondary" =
      {
        device = "/dev/disk/by-uuid/960bc50e-335c-4bd9-acfb-7f00e451396d";
        fsType = "ext4";
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
        Option "metamodes" "DP-2: nvidia-auto-select +1920+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, HDMI-0: nvidia-auto-select +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}"
      '';
      # previous xrandr setup to set screen positions
      # looks like it's still needed to set the primary screen
      displayManager.setupCommands = ''
        ${pkgs.xorg.xrandr}/bin/xrandr --output DP-2 --primary --right-of HDMI-0 || true;
      '';
    };
    # main pc is the media server/nas as well atm
    jellyfin = {
      enable = true;
      openFirewall = true;
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
}
