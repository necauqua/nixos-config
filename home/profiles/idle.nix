{ config, pkgs, lib, osConfig, ... }:
let
  enable = !config.headless && (osConfig.programs.niri.enable or false);

  niri = lib.getExe osConfig.programs.niri.package;
  pgrep = "${pkgs.procps}/bin/pgrep";

  # the lock of Mod+L in the niri config and of the idle timeout below
  lock-screen = pkgs.writeShellScriptBin "lock-screen" ''
    # a second swaylock cannot get the session lock and fails, so do nothing
    # when the session is locked already
    ${pgrep} -xu "$USER" swaylock >/dev/null && exit 0
    exec ${pkgs.swaylock-effects}/bin/swaylock -f -S --clock --effect-blur 7x5 \
      --timestr '%T' --datestr '1%F' --indicator
  '';

  monitors-off = "${niri} msg action power-off-monitors";
in
lib.mkIf enable {
  home.packages = [ lock-screen ];

  # Each input starts a new idle period, and swayidle runs each timeout once
  # per idle period. Any input also makes niri turn the monitors on again.
  services.swayidle = {
    enable = true;
    timeouts = [
      # while the session is locked, the monitors go off after a short time
      {
        timeout = 60;
        command = "${pgrep} -xu \"$USER\" swaylock >/dev/null && ${monitors-off}";
      }
      { timeout = 15 * 60; command = monitors-off; }
      # the lock comes a bit after the monitors go off, so that a false idle
      # timeout needs only a mouse movement and not the password
      { timeout = 15 * 60 + 10; command = lib.getExe lock-screen; }
    ];
  };
}
