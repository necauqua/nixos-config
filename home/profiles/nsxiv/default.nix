{ config, pkgs, lib, ... }: {
  xdg.mimeApps = lib.mkIf pkgs.stdenv.isLinux {
    enable = !config.headless;
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
  xdg.configFile = lib.mkIf pkgs.stdenv.isLinux {
    "mimeapps.list".force = !config.headless;
  };

  home.packages =
    let
      nsxiv =
        (pkgs.nsxiv.overrideAttrs (final: super: {
          patches = (super.patches or [ ]) ++ [ ./config.patch ];
        }));
    in
    lib.optionals (!config.headless) [ nsxiv ];
}
