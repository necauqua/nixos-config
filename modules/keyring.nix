{ pkgs, ... }: {

  # smartcard thing for yubikey
  services.pcscd.enable = true;

  environment.systemPackages = with pkgs; [
    gnome.seahorse
    yubikey-manager
    yubikey-personalization
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    gnome.gnome-keyring.enable = true;
  };

  security.pam.services.sddm.enableGnomeKeyring = true;
}
