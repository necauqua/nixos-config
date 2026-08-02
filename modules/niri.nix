{ pkgs, features, ... }: {
  imports = [ features.gnome features.fcitx ];

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.niri}/bin/niri-session";
        user = "necauqua";
      };
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --asterisks -rtg 'hello' -c niri";
        user = "necauqua";
      };
    };
  };

  programs.niri.enable = true;
  programs.waybar.enable = true;

  # niri-session does an unfiltered `systemctl --user import-environment`, which
  # leaks SHLVL from its login-shell wrapper into the systemd user manager and
  # thus into niri itself. Everything niri spawns (kitty, ...) then inherits
  # SHLVL=1 and shells start at 2. Strip it off the compositor so children start
  # clean at SHLVL=1.
  systemd.user.services.niri.serviceConfig.UnsetEnvironment = "SHLVL";

  environment.systemPackages = [
    pkgs.xwayland-satellite
  ];

  # electron
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
