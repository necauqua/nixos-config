{ pkgs, lib, ... }: {

  options.headless = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = {

    xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";

    xdg.userDirs = {
      enable = true;
      createDirectories = true;

      desktop = "$HOME/";
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      music = "$HOME/music";
      pictures = "$HOME/images";
      publicShare = "$HOME/documents/public";
      templates = "$HOME/documents/templates";
      videos = "$HOME/videos";
    };

    home.packages = with pkgs; [
      nix-tree
      cachix

      iw
      ffmpeg

      man-db
      tldr
      expect
      rlwrap
      jq
      ijq
      jless
      fzf
      nmap
      calc
      traceroute
      dig
      zip
      unzip
      tree
      usbutils
      yt-dlp
      pgcli

      gh
      asciinema
      ripgrep
      ncspot
      screenfetch

      weechat

      exfatprogs
      ntfs3g
      smartmontools

      gifski

      lua5_3.pkgs.luacheck
      lua5_3.pkgs.tl

      nixpkgs-fmt

      packwiz

      awscli2
      ranger
    ];

    xresources.extraConfig = builtins.readFile (pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/arcticicestudio/nord-xresources/c4b8a29871ece1b3a9d9ef792880decdddacd837/src/nord";
      sha256 = "sha256-vsxKcs9RnOcfEKhF72ySg/tDJIE/rKuklwkWJPOpzUc=";
    });

    programs = {
      broot = {
        enable = true;
        settings.verbs = [
          {
            invocation = "mpv";
            execution = "fish -c \"mpvt {file}\"";
            leave_broot = false;
          }
        ];
      };
      bat = {
        enable = true;
        config.style = "numbers";
      };
      direnv.enable = true;
      direnv.nix-direnv.enable = true;
      nix-index.enable = true;
      zoxide.enable = true;
      htop.enable = true;
    };
  };
}
