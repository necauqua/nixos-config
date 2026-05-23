{ pkgs, lib, ... }: {

  options.headless = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = {

    xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";

    xdg.userDirs = lib.mkIf pkgs.stdenv.isLinux {
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

    home.packages = with pkgs;
      let
        linuxOnly = [
          iw
          traceroute
          usbutils
          exfatprogs
          mold
        ];
      in
      [
        nix-tree
        cachix

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
        dig
        zip
        pv
        unzip
        tree
        yt-dlp
        pgcli
        libsecret
        gopass

        gh
        asciinema
        ripgrep
        ncspot
        fastfetch
        semver

        weechat

        nfs-utils
        ntfs3g
        smartmontools

        gifski

        lua5_3.pkgs.luacheck
        lua5_3.pkgs.tl

        nixpkgs-fmt
        nil
        nixd

        packwiz

        twitch-cli
        awscli2
        ranger

        figlet
        basez
        gdb
        just
        pass
        atproto-goat
        websocat
        yq-go
        mmv-go
        radicle-node
        opencode

        gcc
        pkg-config
        rustup
        uv
        zig
        zls # idk move this somewhere?
      ] ++ lib.optionals pkgs.stdenv.isLinux linuxOnly;

    programs = {
      broot.enable = true;
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
