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
      # set explicitly because of old stateVersion, this is the new default
      setSessionVariables = false;

      desktop = "$HOME/";
      documents = "$HOME/documents";
      download = "$HOME/downloads";
      music = "$HOME/music";
      pictures = "$HOME/images";
      projects = "$HOME/projects";
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
        ];
      in
      [
        # nix tools
        nix-tree
        cachix
        nixpkgs-fmt
        nil
        nixd

        # shell/cli utilities
        man-db
        tldr
        expect
        rlwrap
        fzf
        ripgrep
        tree
        ranger
        calc
        pv
        figlet
        basez
        fastfetch

        # data/file processing
        jq
        ijq
        jless
        yq-go
        mmv-go
        zip
        unzip

        # networking
        nmap
        dig
        websocat

        # media
        ffmpeg
        gifski
        yt-dlp
        ncspot

        # filesystem/hardware
        nfs-utils
        ntfs3g
        smartmontools

        # dev toolchains
        gcc
        pkg-config
        mold
        rustup
        uv
        zig
        zls
        gdb
        just
        lua5_3.pkgs.luacheck
        lua5_3.pkgs.tl

        # dev services/vcs
        gh
        radicle-node
        opencode
        pgcli
        semver

        # secrets/auth
        pass
        libsecret
        gopass

        # cloud/services
        awscli2
        twitch-cli
        packwiz

        # social/comms
        weechat
        asciinema
        atproto-goat
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
