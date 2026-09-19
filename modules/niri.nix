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

  systemd.user.services.waybar = {
    # the unit of the package reloads with a bare `kill`, which the unit path
    # has no binary for, because the nixpkgs coreutils does not install one.
    # An Exec* line in a drop-in adds to the list, so the empty assignment is
    # necessary to drop the broken one first.
    serviceConfig = {
      ExecReload = [
        ""
        "${pkgs.util-linux}/bin/kill -SIGUSR2 $MAINPID"
      ];

      # the bar must come back whenever it goes away, not only after a failure
      Restart = "always";
      # a bad config makes waybar exit at once, so wait between the tries and
      # give up after a few of them instead of spinning on a broken config -
      # the waybar-reload path unit starts it again when the config changes
      RestartSec = 2;
    };
    unitConfig = {
      StartLimitIntervalSec = 30;
      StartLimitBurst = 5;
    };

    # the modules of the bar call these, and the unit path holds none of them
    path = with pkgs; [
      bash
      curl
      jq
      libsecret
      swaynotificationcenter
      pavucontrol
    ];
  };

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
