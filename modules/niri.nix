{ pkgs, features, ... }: {
  imports = [ features.gnome ];

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

  environment.systemPackages = [
    pkgs.xwayland-satellite
  ];

  # electron
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
