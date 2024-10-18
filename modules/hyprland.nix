{ pkgs, features, ... }: {
  imports = [ features.gnome ];

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = "necauqua";
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks -rtg 'hello' -c Hyprland";
        user = "necauqua";
      };
    };
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;

    package = pkgs.hyprland.overrideAttrs (prev: {
      src = pkgs.fetchFromGitHub {
        owner = "hyprwm";
        repo = "hyprland";
        fetchSubmodules = true;
        rev = "0e630e9e74ad34683194a07cfe6afe55a2c0685f";
        hash = "sha256-nTMzcwH5eFX2JM5Lrtw1469BRe6hGgWWxLqJBynEdvo=";
      };
    });
  };

  # omg lol
  nixpkgs.overlays = [
    (final: prev: {
      aquamarine = prev.aquamarine.overrideAttrs (prev: {
        src = final.fetchFromGitHub {
          owner = "hyprwm";
          repo = "aquamarine";
          rev = "v0.4.3";
          hash = "sha256-44bnoY0nAvbBQ/lVjmn511yL39Sv7SknV0BDxn34P3Q=";
        };
      });
    })
  ];

  assertions = [{
    assertion = pkgs.hyprland.version == "0.44.1";
    message = "Check if then-bleeding hyprland is still needed";
  }];

  # electron
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
