{ config, pkgs, lib, ... }:
let
  graphical = !config.headless;
in
{
  xsession.enable = graphical;

  home.pointerCursor = {
    package = pkgs.qogir-icon-theme;
    name = "Qogir";
    size = 16;
  };

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

  xdg.mimeApps = {
    enable = graphical;
    defaultApplications = {
      # gimp takes like two eternities to boot while all I need
      # is to see the image lol
      "image/bmp" = "nsxiv.desktop";
      "image/gif" = "nsxiv.desktop";
      "image/jpeg" = "nsxiv.desktop";
      "image/jpg" = "nsxiv.desktop";
      "image/png" = "nsxiv.desktop";
      "image/webp" = "nsxiv.desktop";
      "image/heic" = "nsxiv.desktop";
    };
  };

  # because things just override the link? huh
  xdg.configFile."mimeapps.list".force = graphical;

  # checkLinkTargets seems to happen before writeBoundary.. but this works
  # just setting home.file.".gtkrc-2.0".force = true results in a conflict sadly
  home.activation.resetGtkrc2 = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f $VERBOSE_ARG $HOME/.gtkrc-2.0
  '';

  services = {
    kdeconnect.enable = true;
    betterlockscreen = {
      enable = true;
      arguments = [ "blur" ];
    };
    caffeine.enable = true;
    swaync.enable = true;
  };

  home.packages = with pkgs; lib.optionals graphical [
    dex
    xclip

    xdotool
    libnotify
    wmctrl

    thunderbird

    tdesktop
    (makeAutostartItem { name = "org.telegram.desktop"; package = tdesktop; })

    nsxiv
    maim
    d-spy
    pavucontrol
    qpwgraph
    barrier

    transmission_4-gtk
    carla
    noise-repellent
    peek
    chatterino2
    bitwarden
    (discord.override { withOpenASAR = true; })
    mumble
    element-desktop
    emote
    lmms
    evince
    file-roller

    audacity
    gimp
    blender
    jetbrains.idea-ultimate
    android-studio
    godot3
    vscode
    # logseq # depends on eol electron atm
    obsidian
    via

    starsector
    prismlauncher # multimc fork that works on Nix from the box
    lutris
    winetricks # needed for lutris among other things

    solaar
    songrec
    ghidra
    pyhidra

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
