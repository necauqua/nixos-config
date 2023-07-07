{ config, pkgs, lib, ... }: {

  imports = [ ./main-hardware.nix ];

  networking.hostName = "main";

  boot = {
    bootspec.enable = true;
    loader.systemd-boot.enable = lib.mkForce false;
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
    kernelParams = [
      "libata.allow_tmp=1"
    ];
    zfs.extraPools = [ "archive" ];
  };

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
  environment.etc."pipewire/pipewire.conf.d/focusrite.conf".text = ''
    {
      "context.properties": {
        "default.clock.rate": 192000
      }
    }
  '';

  # cooler control stuff
  hardware.gkraken.enable = true;
}
