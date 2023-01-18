{ pkgs, config, ... }:
let
  toml = pkgs.formats.toml {};
  wrap = pkg: flags:
    pkgs.runCommand pkg {
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

  tdesktop = (wrap pkgs.tdesktop "--set LC_TIME C");

in {

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
    fortune
    lolcat
    figlet
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
    jless
    wmctrl
    (youtube-dl.overrideAttrs (super: {
      patches = super.patches ++ [
        (fetchpatch {
          name = "fix-a-thing.patch";
          url = "https://github.com/ytdl-org/youtube-dl/commit/23ad6402a6966dd09e4c854f32c33f69be1a064e.diff";
          sha256 = "sha256-jopn8BOJA7DNY3xwGZqGyOvz2qRlSC3PBtIObCWXQRE=";
        })
      ];
    }))

    gh
    asciinema
    ripgrep
    ncspot
    screenfetch
    zellij
    delta

    (wrap firefox "--set MOZ_USE_XINPUT2 1")

    tdesktop
    (makeAutostartItem { name = "org.telegram.desktop"; package = tdesktop; })
  
    sxiv
    maim
    gnome.baobab
    gnome.nautilus
    gnome.zenity
    gnome.file-roller
    dfeet
    pavucontrol
    qjackctl
    barrier
    
    gparted
    exfatprogs
    ntfs3g
    smartmontools
    
    nomachine-client
    transmission-gtk
    carla
    noise-repellent
    peek
    gifski
    chatterino2
    bitwarden
    # fix opening links from discord
    (discord.override { nss = nss_latest; })
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
    godot
    sublime4
    vscode
    logseq
    shadered
    via

    rustup

    lua5_3.pkgs.luacheck
    lua5_3.pkgs.tl

    # LSPs
    python3Packages.python-lsp-server
    
    nixpkgs-fmt

    minecraft
    starsector
    prismlauncher # multimc fork that works on Nix from the box
    packwiz
    lutris
    winetricks # needed for lutris among other things

    solaar
    (pkgs.writeShellScriptBin "prime-run" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec -a "$0" "$@"
    '')
  ];

  home.pointerCursor = {
    x11.enable = true;
    package = pkgs.qogir-icon-theme;
    name = "Qogir";
    size = 48;
  };

  xresources.extraConfig = builtins.readFile(pkgs.fetchurl {
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
        key = "FFD8502A";
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
        core.pager = "delta";
        interactive.diffFilter = "delta --color-only";
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
    # neovim = {
    #   enable = true;
    #   extraConfig = ''
    #     set runtimepath^=~/.vim runtimepath+=~/.vim/after
    #     let &packpath = &runtimepath
    #     source ~/.vimrc
    #   '';
    # };
    helix = {
      enable = true;
      settings = {
        keys.normal = {
          "C-q" = "hover";
          "C-k" = "command_palette";
        };
      };
      languages = [
        {
          name = "nix";
          indent = { tab-width = 2; unit = "  "; };
          language-server = { command = "${pkgs.rnix-lsp}/bin/rnix-lsp"; };
        }
        {
          name = "rust";
          config.checkOnSave.command = "clippy";
        }
      ];
    };
    rofi = {
      enable = true;
      font = "JetBrains Mono 12";
      terminal = "alacritty";
      theme =
        let
          lit = config.lib.formats.rasi.mkLiteral;
        in {
          "@import" = "default";
          "*" = {
            background = lit "black/50%";
            foreground = lit "white";
          };
          window = {
            fullscreen = true;
            padding = lit "25%";
            border = 0;
          };
          prompt.enabled = false;
          textbox-prompt-colon.str = "λ";
          entry = {
            text-color = lit "rgba(0, 255, 255, 100%)";
            placeholder = "search";
            placeholder-color = lit "white/50%";
          };
          message = {
            border = 0;
            padding = lit "1ch 0";
          };
          listview = {
            columns = 2;
            fixed-columns = true;
            padding = lit "2ch 0 0 0";
            scrollbar = false;
            dynamic = true;
          };
          element-icon = {
            size = lit "2ch";
            padding = lit "0.25ch 0.25ch 0 0";
          };
          element = {
            padding = lit "0.5ch";
            background-color = lit "transparent";
          };
          "element normal normal".background-color = lit "transparent";
          "element alternate normal".background-color = lit "transparent";
        };
      extraConfig = {
        modi = "window,run,ssh,windowcd,combi";
        combi-hide-mode-prefix = true;
        dpi = 1;
      };
    };
    mpv = {
      enable = true;
      
      package = pkgs.wrapMpv pkgs.mpv-unwrapped {
         scripts = [ pkgs.mpvScripts.mpris ]; # add an essential script lol
      };
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

  services = {
    picom = {
      enable = true;
      package = pkgs.picom-next;
      settings = {
        backend = "glx";
        blur-background = true;
        blur-background-exclude = [
          "window_type = 'dock'"
          "window_type = 'desktop'"
          "class_g = 'Peek'"
          "class_g = 'slop'"
          "class_g = 'firefox'" # firefox menus
          "class_g = 'TelegramDesktop'" # telegram menus too
        ];
        blur = {
          method = "dual_kawase";
          strength = 4;
        };
        dbus = true;
        unredir-if-possible = true;
      };
    };
    udiskie.enable = true;
  };

  xdg.configFile = {
    "nixpkgs/config.nix".text = "{ allowUnfree = true; }";
    "greenclip.toml".source = toml.generate "greenclip-config" {
      greenclip = {
        max_history_length = 100;
        trim_space_from_selection = false;
        # defaults that greenclip still requires to be present:
        max_selection_size_bytes = 0;
        history_file = "/home/necauqua/.cache/greenclip.history";
        image_cache_directory = "/tmp/greenclip";
        use_primary_selection_as_input = false;
        blacklisted_applications = [];
        enable_image_support = false;
        static_history = [];
      };
    };
  };

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

  # workaround for things that need the tray.target (e.g. udiskie)
  systemd.user.targets.tray = {
    Unit = {
      Description = "Home Manager System Tray";
      Requires = [ "graphical-session-pre.target" ];
    };
  };

  home.stateVersion = "22.11";
}
