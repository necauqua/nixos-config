{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    gnomeExtensions.appindicator
    adwaita-icon-theme
  ];
  services.udev.packages = with pkgs; [
    gnome-settings-daemon
  ];
  xdg.portal = {
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    configPackages = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
}
