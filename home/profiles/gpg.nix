{ config, pkgs, lib, ... }: {

  programs.gpg = {
    enable = true;
    # scdaemonSettings.disable-ccid = true;
  };

  programs.git.extraConfig = {
    commit.gpgSign = true;
    tag.gpgSign = true;
  };

  home.packages = lib.optionals (!config.headless) (with pkgs; [
    seahorse
  ]);
}
