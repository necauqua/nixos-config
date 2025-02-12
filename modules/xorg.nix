{ pkgs, lib, ... }: {

  environment.variables = {
    # no idea why is this not a default on an X11 systems
    QT_USE_PHYSICAL_DPI = "1";

    # make firefox way better with touchscreen/touchpad and stuff
    MOZ_USE_XINPUT2 = "1";
  };

  services = {
    displayManager.autoLogin = {
      enable = true;
      user = "necauqua";
    };
    xserver = {
      enable = true;
      dpi = 196;

      excludePackages = [ pkgs.xorg.xorgserver ];
      displayManager = {
        xserverBin = lib.mkForce "${pkgs.xserver-bug865}/bin/X";
        # xserverArgs = ["-extension" "MIT-SHM"];
        # # ^ getting BadValue crashes in wine/lutris games without this
        # ^ but it prevents OBS from capturing the screen (obviously), lol
      };
      windowManager.bspwm.enable = true;

      # Configure keymap in X11
      xkb = {
        layout = "us,ru";
        options = lib.mkDefault "grp:alt_shift_toggle,compose:rwin";
      };
    };
  };
}
