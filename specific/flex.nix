{ config, pkgs, lib, ... }: {

  imports = [ ./flex-hardware.nix ];

  networking.hostName = "flex";

  nix.settings.max-jobs = 8;

  services.xserver = {
    # enable touchpad and also make it faster for the 4k display
    libinput = {
      enable = true;
      touchpad = {
        accelSpeed = "0.6";
        naturalScrolling = true;
      };
    };
    # some xrangr magic to fix touchpad display
    # along with xinput+unclutter to fix/prettify the touchscreen
    displayManager.setupCommands = ''
      XRANDR=${pkgs.xorg.xrandr}/bin/xrandr
      $XRANDR --newmode "1080x2160" 200.61 1080 1168 1288 1496 2160 2161 2164 2235 -hsync +vsync
      $XRANDR --addmode HDMI-1-1 1080x2160
      ${pkgs.xorg.xinput}/bin/xinput --map-to-output "pointer:ELAN9008:00 04F3:2A46" eDP-1-1
      ${pkgs.unclutter-xfixes}/bin/unclutter --hide-on-touch -b
    '';
    screenSection = ''
      Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      Option "AllowIndirectGLXProtocol" "off"
      Option "TripleBuffer" "on"
    '';
  };

  # do the nvidia+intel laptop magic
  hardware.nvidia = {
    modesetting.enable = true;
    prime = {
      sync.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:2:0:0";
    };
  };

  # so the battery widget can get status from dbus
  services.upower.enable = true;
}
