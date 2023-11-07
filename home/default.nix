{ pkgs, ... }:
let
  wrap = pkg: flags:
    pkgs.runCommand pkg
      {
        buildInputs = [ pkgs.makeWrapper ];
      } ''
      mkdir $out
      # Link every top-level folder from pkg to our new target
      ln -s ${pkg}/* $out
      # Except the bin folder
      rm $out/bin
      # We create the bin folder ourselves and link every binary in it
      mkdir $out/bin
      ln -s ${pkg}/bin/* $out/bin
      # Except the binary
      rm $out/bin/${pkg.pname}
      # Because we create it ourself, by creating a wrapper
      makeWrapper ${pkg}/bin/${pkg.pname} $out/bin/${pkg.pname} --inherit-argv0 ${flags}

      # Repeat the same thing to have real share/applications copied
      rm $out/share
      mkdir $out/share
      ln -s ${pkg}/share/* $out/share

      rm $out/share/applications
      mkdir $out/share/applications
      # for some weird reason cp -r applications did not work (the copied folder had some temp file which threw off sed _somehow_)
      cp ${pkg}/share/applications/*.desktop $out/share/applications

      # And substitute paths in the desktop files
      sed -i s%${pkg}%$out%g $out/share/applications/*.desktop
    '';

  tdesktop = (wrap pkgs.tdesktop "--set LC_TIME C --set XDG_CURRENT_DESKTOP gnome");

in
{

  imports = [
    ./terminal.nix
  ];

  home.packages = with pkgs; [
    nix-tree
    cachix

    dex
    iw
    xclip
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
    xdotool
    calc
    traceroute
    dig
    zip
    unzip
    tree
    usbutils
    libnotify
    wmctrl
    yt-dlp

    gh
    asciinema
    ripgrep
    ncspot
    screenfetch
    zellij

    (wrap firefox "--set MOZ_USE_XINPUT2 1")
    thunderbird

    tdesktop
    (makeAutostartItem { name = "org.telegram.desktop"; package = tdesktop; })

    sxiv
    maim
    dfeet
    pavucontrol
    qpwgraph
    barrier
    kgpg

    exfatprogs
    ntfs3g
    smartmontools

    transmission-gtk
    carla
    noise-repellent
    peek
    gifski
    chatterino2
    bitwarden
    (discord.override { withOpenASAR = true; })
    element-desktop
    spotify
    tidal-hifi
    emote
    lmms
    evince

    audacity
    gimp
    blender
    obs-studio
    jetbrains.idea-ultimate
    android-studio
    godot3
    vscode
    # logseq # depends on eol electron atm
    obsidian
    via

    lua5_3.pkgs.luacheck
    lua5_3.pkgs.tl

    nixpkgs-fmt

    minecraft
    starsector
    prismlauncher # multimc fork that works on Nix from the box
    packwiz
    lutris
    winetricks # needed for lutris among other things

    solaar
    songrec
    awscli2
    ranger

    (pkgs.writeShellScriptBin "prime-run" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec -a "$0" "$@"
    '')
    (pkgs.writeShellScriptBin ":wq" "kill $PPID")
  ];

  xsession.enable = true;

  home.pointerCursor = {
    x11.enable = true;
    package = pkgs.qogir-icon-theme;
    name = "Qogir";
    size = 48;
  };

  xresources.extraConfig = builtins.readFile (pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/arcticicestudio/nord-xresources/c4b8a29871ece1b3a9d9ef792880decdddacd837/src/nord";
    sha256 = "sha256-vsxKcs9RnOcfEKhF72ySg/tDJIE/rKuklwkWJPOpzUc=";
  });

  gtk = {
    enable = true;
    iconTheme = {
      # name = "Adwaita";
      # package = pkgs.gnome.adwaita-icon-theme;
      name = "breeze-dark";
      package = pkgs.breeze-icons;
    };
    theme = {
      # name = "Adwaita-dark";
      # package = pkgs.gnome3.gnome-themes-extra;
      name = "Breeze-Dark";
      package = pkgs.breeze-gtk;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "menu:";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "menu:";
    };
  };

  # manual.manpages.enable = false;

  programs = {
    git = {
      enable = true;
      userName = "Anton Bulakh";
      userEmail = "self@necauqua.dev";
      aliases.rtag = "!f(){ git tag --message=\"Release \${1}\n\" \${1}; }; f";
      signing = {
        key = "29511C06755C211BB3D3419342997635A54BA55B";
        signByDefault = true;
      };
      extraConfig = {
        init.defaultBranch = "main";
        core.autocrlf = "input";
        commit.gpgSign = true;
        tag.gpgSign = true;
        push.followTags = true;
        push.default = "current";
        pull.ff = "only";
        fetch.prune = "true";

        # delta settings
        core.pager = "${pkgs.delta}/bin/delta";
        interactive.diffFilter = "${pkgs.delta}/bin/delta --color-only";
        "add.interactive".useBuiltin = false;
        delta = { navigate = true; light = false; };
        merge.conflictstyle = "diff3";
        diff.colorMoved = "default";
      };
    };
    bat = {
      enable = true;
      config.style = "numbers";
    };
    helix = {
      enable = true;
      settings = {
        keys.normal = {
          "C-q" = "hover";
          "C-k" = "command_palette";
        };
      };
      languages = {
        language-server = {
          nil.command = "${pkgs.nil}/bin/nil";
          rust-analyzer = {
            command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
            config.checkOnSave.command = "clippy";
          };
          pylsp.command = "${pkgs.python3Packages.python-lsp-server}/bin/pylsp";
        };
        language = [
          {
            name = "nix";
            indent = { tab-width = 2; unit = "  "; };
            language-servers = [ "nil" ];
            formatter.command = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt";
            auto-format = true;
          }
          {
            name = "rust";
            language-servers = [ "rust-analyzer" ];
          }
          {
            name = "python";
            language-servers = [ "pylsp" ];
          }
        ];
      };
    };
    mpv = {
      enable = true;

      package = (pkgs.mpv.override {
        scripts = [ pkgs.mpvScripts.mpris ]; # add an essential script lol
      });
      config = {
        volume = 60;
        volume-max = 200;
        pause = true;
        save-position-on-quit = true;

        audio-display = false;
        term-osd-bar = true;
        term-osd-bar-chars = "┣━╉─┨";

        screenshot-format = "png";
        screenshot-template = "mpv-1%tY%tm%td%tH%tM%tS%01n";

        hwdec = true;
        hwdec-codecs = "all";
        profile = "gpu-hq";
      };
      bindings = {
        "9" = "add ao-volume -1";
        "/" = "add ao-volume -1";
        "0" = "add ao-volume 1";
        "*" = "add ao-volume 1";

        WHEEL_LEFT = "seek 10";
        WHEEL_RIGHT = "seek -10";
        WHEEL_UP = "add ao-volume 1";
        WHEEL_DOWN = "add ao-volume -1";

        VOLUME_UP = "add ao-volume 1";
        VOLUME_DOWN = "add ao-volume -1";

        # reload file - useful when YouTube stream link expires
        "Ctrl+r" = "loadfile \${path} replace";

        # yank same as in vim or luakit
        y = "run \"/usr/bin/env\" \"bash\" \"-c\" \"echo -n '\${path}' | xclip -i\"; show-text \"Path yanked: \${path}\"";
        Y = "run \"/usr/bin/env\" \"bash\" \"-c\" \"echo -n '\${path}' | xclip -i -sel clip\"; show-text \"Path yanked to clipboard: \${path}\"";

        # disable pause (there is space, huh) for p- clipboard commands
        p = "ignore";
        # same for progress, there is 'o' button
        P = "ignore";
      };
    };
  };

  services.kdeconnect.enable = true;

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

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # gimp takes like two eternities to boot while all I need
      # is to see the image lol
      "image/bmp" = "sxiv.desktop";
      "image/gif" = "sxiv.desktop";
      "image/jpeg" = "sxiv.desktop";
      "image/jpg" = "sxiv.desktop";
      "image/png" = "sxiv.desktop";
      "image/webp" = "sxiv.desktop";
      "image/heic" = "sxiv.desktop";
    };
  };

  # because things just override the link? huh
  xdg.configFile."mimeapps.list".force = true;

  home.stateVersion = "22.11";
}
