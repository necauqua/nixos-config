{ pkgs, lib, ... }: {
  services.xserver = {
    enable = true;
    dpi = 196;

    excludePackages = [ pkgs.xorg.xorgserver ];
    displayManager = {
      xserverBin = lib.mkForce "${pkgs.xserver-bug865}/bin/X";
      # xserverArgs = ["-extension" "MIT-SHM"];
      # # ^ getting BadValue crashes in wine/lutris games without this
      # ^ but it prevents OBS from capturing the screen (obviously), lol
    };
    windowManager.leftwm.enable = true;

    # Configure keymap in X11
    xkb = {
      layout = "us,ru";
      options = lib.mkDefault "grp:alt_shift_toggle,compose:rwin";
    };
  };
}
