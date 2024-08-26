{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # electron
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
