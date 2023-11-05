{ pkgs, username, ... }: {

  # smartcard daemon for ykman to work
  services.pcscd.enable = true;
  # note, also need this to stop annoying conflicts with gpg:
  home-manager.users.${username}.home.file.".gnupg/scdaemon.conf".text = "disable-ccid";

  environment.systemPackages = with pkgs; [
    gnome.seahorse
    yubikey-manager
    yubikey-personalization
  ];

  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    yubikey-touch-detector.enable = true;
  };

  services = {
    udev.packages = [ pkgs.yubikey-personalization ];
    gnome.gnome-keyring.enable = true;
  };

  security.pam = {
    u2f = {
      enable = true;
      cue = true;

      # nix shell nixos#pam_u2f
      # pamu2fcfg > file; pamu2fcfg -n >> file # for subsequent keys
      # move there, chmod+chown, yadda yadda
      authFile = "/etc/u2f_mapping";
    };
    services.sddm.enableGnomeKeyring = true;
  };
}
