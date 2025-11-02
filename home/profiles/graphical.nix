{ config, pkgs, lib, osConfig, ... }:
let
  graphical = !config.headless;
  x11 = osConfig.services.xserver.enable;
in
{
  xsession.enable = pkgs.stdenv.isLinux && graphical;

  home.pointerCursor = lib.mkIf pkgs.stdenv.isLinux {
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

  services = {
    betterlockscreen = {
      enable = graphical && x11;
      arguments = [ "blur" ];
    };
    caffeine.enable = pkgs.stdenv.isLinux && graphical;
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

    transmission_4-gtk
    # carla
    noise-repellent
    peek
    chatterino2
    bitwarden-desktop
    (discord.override { withOpenASAR = true; })
    mumble
    element-desktop
    emote
    # lmms
    evince
    file-roller

    audacity
    gimp
    blender
    jetbrains.idea-ultimate
    android-studio
    godot3
    vscode
    zed-editor
    obsidian
    via

    starsector
    prismlauncher # multimc fork that works on Nix from the box
    lutris
    winetricks # needed for lutris among other things

    solaar
    songrec
    ghidra

    playerctl
    zenity
    kitty # todo configure through nix

    feh
    imhex
    quickemu
    fractal
    kdePackages.dolphin

    # wayland-only, todo maybe check that x11 boolean
    #  could also move to the hyprland module or something
    grim
    slurp
    wf-recorder
    wl-clipboard-rs
    waybar
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
