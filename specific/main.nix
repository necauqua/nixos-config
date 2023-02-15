{ config, pkgs, lib, ... }: {

  imports = [ ./main-hardware.nix ];
  
  networking.hostName = "main";

  boot.zfs.extraPools = [ "archive" ];

  # free up some cores to keep consuming that content
  # from the second monitor while packages are rebuilt
  nix.settings.max-jobs = 18;

  services.xserver = {
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

  # cooler control stuff
  hardware.gkraken.enable = true;
}
