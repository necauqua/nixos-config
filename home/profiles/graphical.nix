{ config, pkgs, lib, osConfig, ... }:
let
  graphical = !config.headless;
  x11 = osConfig.services.xserver.enable;
in
{
  xsession.enable = pkgs.stdenv.hostPlatform.isLinux && graphical;

  home.pointerCursor = {
    enable = pkgs.stdenv.hostPlatform.isLinux;
    package = pkgs.qogir-icon-theme;
    name = "Qogir";
    size = 16;
  };

  xresources.extraConfig = "Xft.dpi: ${if x11 then "96" else "196"}";

  gtk = {
    enable = graphical;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    # set explicitly because of old stateVersion, this is the new default
    gtk4.theme = null;
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "menu:";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-decoration-layout = "menu:";
    };
  };

  qt = {
    enable = graphical;
    platformTheme.name = "Adwaita-dark";
    style = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  # checkLinkTargets seems to happen before writeBoundary.. but this works
  # just setting home.file.".gtkrc-2.0".force = true results in a conflict sadly
  home.activation.resetGtkrc2 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f $VERBOSE_ARG $HOME/.gtkrc-2.0
  '';

  # these configs live in configs/ of the flake and are linked, not generated,
  # so that a tweak applies without a rebuild
  custom.config-links.links = lib.optionals graphical [
    { name = "niri"; dest = ".config/niri"; }
    { name = "waybar"; dest = ".config/waybar"; }
    { name = "kitty"; dest = ".config/kitty"; }
  ];

  # niri and kitty watch their own config, waybar needs a signal
  systemd.user = lib.mkIf graphical {
    paths.waybar-reload = {
      Unit.Description = "Watch the waybar config for changes";
      Path = {
        PathChanged = "%h/.config/waybar";
        Unit = "waybar-reload.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    services.waybar-reload = {
      Unit.Description = "Reload waybar";
      Service = {
        Type = "oneshot";
        # a broken config kills waybar, and enough fast restarts put the unit
        # in the failed state, where systemd refuses to start it again. So drop
        # that state first (the `-` ignores the failure when there is none) and
        # use reload-or-restart, which, unlike the `try-` form, also starts a
        # unit that is not running - that is what brings waybar back once the
        # config is valid again.
        ExecStart = [
          "-${pkgs.systemd}/bin/systemctl --user reset-failed waybar.service"
          "${pkgs.systemd}/bin/systemctl --user reload-or-restart waybar.service"
        ];
      };
    };
  };

  services = {
    betterlockscreen = {
      enable = graphical && x11;
      arguments = [ "blur" ];
    };
    caffeine.enable = pkgs.stdenv.hostPlatform.isLinux && graphical;
    swaync.enable = graphical && !x11;
  };

  home.packages = with pkgs; lib.optionals graphical [
    dex
    xclip

    xdotool
    libnotify
    wmctrl

    thunderbird

    telegram-desktop
    (makeAutostartItem { name = "org.telegram.desktop"; package = telegram-desktop; })

    maim
    d-spy
    pavucontrol
    qpwgraph

    chatterino2
    bitwarden-desktop
    (discord.override { withOpenASAR = true; })
    vesktop
    mumble
    emote
    # lmms
    evince
    file-roller
    keepassxc
    ungoogled-chromium

    audacity
    gimp
    blender
    # jetbrains.idea
    # android-studio
    zed-editor
    obsidian

    starsector
    prismlauncher # multimc fork that works on Nix from the box
    lutris
    wineWow64Packages.staging
    winetricks # needed for lutris among other things

    solaar
    songrec
    ghidra

    playerctl
    zenity
    kitty # todo configure through nix

    # feh
    imhex
    quickemu
    kdePackages.dolphin

    # wayland-only, todo maybe check that x11 boolean
    #  could also move to the hyprland module or something
    grim
    slurp
    wf-recorder
    wl-clipboard-rs
    waybar
    wayscriber
    swaybg
    swaylock-effects


    (pkgs.writeShellScriptBin "prime-run" ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec -a "$0" "$@"
    '')
    (pkgs.writeShellScriptBin ":wq" "kill $PPID")
  ];
}
