{ pkgs, ... }: {

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = "necauqua";
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks -rtg 'hello' -s Hyprland";
        user = "necauqua";
      };
    };
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # electron
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
