{ config, pkgs, lib, ... }: {

  imports = [ ./main-hardware.nix ];
  
  networking.hostName = "main";

  boot.zfs.extraPools = [ "archive" ];
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
    pipewire = {
      config.pipewire = {
        "context.properties" = {
          # focusrite scarlett 2i2
          "default.clock.rate" = 192000;
          # allowing all rates causes cracks
          # when it flips between default of 44.1 and
          # 48 of a yt video in firefox, especially when you seek
          # "default.clock.allowed-rates" =
          #   [ 44100 48000 88200 96000 176400 192000 ];
          "link.max-buffers" = 16;
        };
      };
    };
  };

  # cooler control stuff
  hardware.gkraken.enable = true;
}
