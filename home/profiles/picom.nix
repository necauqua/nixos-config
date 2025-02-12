{ config, pkgs, osConfig, ... }: {
  services.picom = {
    enable = !config.headless && osConfig.services.xserver.enable;
    package = pkgs.picom-next;
    settings = {
      backend = "glx";
      blur-background = true;
      blur-background-exclude = [
        "window_type = 'dock'"
        "window_type = 'desktop'"
        "class_g = 'Peek'"
        "class_g = 'slop'"
        "class_g = 'firefox'" # firefox menus
        "class_g = 'TelegramDesktop'" # telegram menus too
      ];
      blur = {
        method = "dual_kawase";
        strength = 4;
      };
      dbus = true;
      unredir-if-possible = true;
    };
  };
}
