{ config, pkgs, lib, ... }:
let
  graphical = !config.headless;
  wrap = pkg: flags:
    pkgs.runCommand pkg { buildInputs = [ pkgs.makeWrapper ]; } ''
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
  xsession.enable = graphical;

  home.pointerCursor = {
    x11.enable = graphical;
    package = pkgs.qogir-icon-theme;
    name = "Qogir";
    size = 48;
  };

  gtk = {
    enable = graphical;
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
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "menu:";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-decoration-layout = "menu:";
    };
  };

  xdg.mimeApps = {
    enable = graphical;
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
  xdg.configFile."mimeapps.list".force = graphical;

  services.kdeconnect.enable = true;

  home.packages = with pkgs; lib.optionals graphical [
    dex
    xclip

    xdotool
    libnotify
    wmctrl

    (wrap firefox "--set MOZ_USE_XINPUT2 1")
    thunderbird

    tdesktop
    (makeAutostartItem { name = "org.telegram.desktop"; package = tdesktop; })

    sxiv
    maim
    d-spy
    pavucontrol
    qpwgraph
    barrier

    transmission-gtk
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

    minecraft
    starsector
    prismlauncher # multimc fork that works on Nix from the box
    lutris
    winetricks # needed for lutris among other things

    solaar
    songrec

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
