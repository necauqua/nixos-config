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
      starship = {
        enable = true;
        settings = {
          add_newline = false;
          right_format = "$directory";
          character = {
            success_symbol = "λ";
            error_symbol = "λ";
          };
          directory = {
            truncation_length = 10;
            fish_style_pwd_dir_length = 1;
          };
          status = {
            disabled = false;
            format = "[$status](red)";
            pipestatus = true;
            pipestatus_format = "[$pipestatus](red) ";
          };
          nix_shell = {
            symbol = "❄️";
            impure_msg = "";
          };
          git_branch = {
            format = "on [⌥](purple) [$branch(:$remote_branch)](#ff6611) ";
            only_attached = true;
          };
          git_commit.format = "on [⌥](purple) [$hash](#ffaa33) ";
          git_status = {
            format = "(\\([$ahead_behind](#aaaaaa)\\) )(\\[$conflicted$stashed$staged$renamed$modified$deleted$untracked\\] )";
            conflicted = "=$count";
            stashed = "\\$$count";
            staged = "[+$count](#33cc33)";
            renamed = "[~$count](#6666ff)";
            modified = "[~$count](#6666ff)";
            deleted = "[-$count](#cc3333)";
            untracked = "[#$count](#cc3333)";
            ahead = "↑$count";
            behind = "↓$count";
            diverged = "↑$ahead_count↓$behind_count";
          };
          aws.disabled = true;
        };
      };
    };
  };
}
