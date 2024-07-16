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
