{ pkgs, ...}: {

  programs.gpg = {
    enable = true;
    scdaemonSettings.disable-ccid = true;
  };

  programs.git.extraConfig = {
    commit.gpgSign = true;
    tag.gpgSign = true;
  };

  home.packages = with pkgs; [
    kgpg
    gnome.seahorse
  ];
}